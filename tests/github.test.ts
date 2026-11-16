import { afterEach, describe, expect, it, vi } from 'vitest';
import { createClient, GitHubError } from '../src/github.ts';

type Answer = Response | Error;

/** fetch answering with `answers` in turn; the client's waits are recorded instead of slept. */
function setup(answers: Answer[], options: { maxWaitMs?: number } = {}) {
  const fetch = vi.fn(async () => {
    const next = answers.shift();
    if (!next) throw new Error('no more answers');
    if (next instanceof Error) throw next;
    return next;
  });
  vi.stubGlobal('fetch', fetch);
  const waits: number[] = [];
  const logs: string[] = [];
  const client = createClient('token', (m) => logs.push(m), {
    sleep: async (ms) => void waits.push(ms),
    ...options,
  });
  return { client, fetch, waits, logs };
}

const ok = (data: unknown = { viewer: { login: 'octo' } }, extra: object = {}) =>
  new Response(JSON.stringify({ data, ...extra }), { status: 200 });
const status = (code: number, body = '', headers: Record<string, string> = {}) => new Response(body, { status: code, headers });
const timeout = () => Object.assign(new Error('The operation was aborted due to timeout'), { name: 'TimeoutError' });

afterEach(() => vi.unstubAllGlobals());

describe('GitHub client', () => {
  it('tries again when GitHub has an error of its own', async () => {
    const { client, fetch, waits } = setup([status(502), ok()]);
    expect(await client.query('query { viewer { login } }')).toEqual({ viewer: { login: 'octo' } });
    expect(fetch).toHaveBeenCalledTimes(2);
    expect(waits).toEqual([2000]);
  });

  it('gives up straight away on a 403 that is not a rate limit', async () => {
    const { client, fetch, waits } = setup([status(403, '{"message":"Resource not accessible by integration"}')]);
    await expect(client.query('q')).rejects.toThrow('GitHub answered 403: {"message":"Resource not accessible');
    expect(fetch).toHaveBeenCalledTimes(1);
    expect(waits).toEqual([]);
  });

  it('waits for an exhausted rate limit to reset', async () => {
    const reset = Math.floor(Date.now() / 1000) + 30;
    const { client, waits, logs } = setup([
      status(403, 'API rate limit exceeded', { 'x-ratelimit-remaining': '0', 'x-ratelimit-reset': String(reset) }),
      ok(),
    ]);
    await client.query('q');
    expect(waits[0]).toBeGreaterThan(25_000);
    expect(waits[0]).toBeLessThanOrEqual(30_000);
    expect(logs[0]).toMatch(/rate limit, retrying in/);
  });

  it('waits on a secondary rate limit, as long as Retry-After says', async () => {
    const { client, waits } = setup([status(403, 'You have exceeded a secondary rate limit', { 'retry-after': '7' }), ok()]);
    await client.query('q');
    expect(waits).toEqual([7000]);
  });

  it('tries again on 429', async () => {
    const { client, waits } = setup([status(429), ok()]);
    await client.query('q');
    expect(waits).toEqual([2000]);
  });

  it("fails instead of waiting longer than the run can", async () => {
    const reset = Math.floor(Date.now() / 1000) + 3600;
    const { client, waits } = setup([status(403, '', { 'x-ratelimit-remaining': '0', 'x-ratelimit-reset': String(reset) })]);
    await expect(client.query('q')).rejects.toThrow(/resets in 60 minutes, too long to wait/);
    expect(waits).toEqual([]);
  });

  it('tries again when GitHub cannot be reached', async () => {
    const { client, fetch, waits } = setup([new TypeError('fetch failed'), new TypeError('fetch failed'), ok()]);
    await client.query('q');
    expect(fetch).toHaveBeenCalledTimes(3);
    expect(waits).toEqual([2000, 4000]);
  });

  it('gives up after four tries without an answer', async () => {
    const { client, fetch } = setup([timeout(), timeout(), timeout(), timeout()]);
    const error = await client.query('q').catch((e: unknown) => e);
    expect(error).toBeInstanceOf(GitHubError);
    expect((error as Error).message).toBe('GitHub did not answer within 30s');
    expect(fetch).toHaveBeenCalledTimes(4);
  });

  it('sends a timeout with every request', async () => {
    const { client, fetch } = setup([ok()]);
    await client.query('q');
    const init = (fetch.mock.calls[0] as unknown as [string, RequestInit])[1];
    expect(init.signal).toBeInstanceOf(AbortSignal);
  });

  it('stops on a rejected token', async () => {
    const { client, fetch } = setup([status(401)]);
    await expect(client.query('q')).rejects.toThrow('the token was rejected (401)');
    expect(fetch).toHaveBeenCalledTimes(1);
  });

  it("tries again on GraphQL's own rate limit error", async () => {
    const { client, fetch } = setup([
      new Response(JSON.stringify({ errors: [{ type: 'RATE_LIMITED', message: 'API rate limit exceeded' }] }), { status: 200 }),
      ok(),
    ]);
    await client.query('q');
    expect(fetch).toHaveBeenCalledTimes(2);
  });

  it('keeps partial data, with the refused parts as warnings', async () => {
    const { client } = setup([ok({ user: null }, { errors: [{ type: 'FORBIDDEN', message: 'SAML enforcement', path: ['org'] }] })]);
    expect(await client.query('q')).toEqual({ user: null });
    expect(client.warnings).toEqual(['SAML enforcement (at org)']);
  });
});
