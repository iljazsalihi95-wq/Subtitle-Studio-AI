// OpenAI proxy for private testing. Never embed API keys or access tokens in an APK.
// Requires both OPENAI_API_KEY and BACKEND_ACCESS_TOKEN as Cloudflare Secrets.
const SERVICE = "subtitle-studio-ai-api";
const INSTRUCTION = "Translate subtitle text into standard Albanian while preserving meaning, repetitions, Islamic terminology when relevant, and line breaks. Return only the translation.";
const MAX_CHARS = 6000;
const MAX_OUTPUT_TOKENS = 700;

function json(data, status = 200) {
  return Response.json(data, { status, headers: {
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff',
  } });
}

function authorized(request, secret) {
  if (!secret || typeof secret !== 'string' || secret.length < 32) return false;
  const header = request.headers.get('Authorization') || '';
  const prefix = 'Bearer ';
  if (!header.startsWith(prefix)) return false;
  const supplied = header.slice(prefix.length);
  if (supplied.length !== secret.length) return false;
  let difference = 0;
  for (let i = 0; i < secret.length; i++) difference |= supplied.charCodeAt(i) ^ secret.charCodeAt(i);
  return difference === 0;
}

export default {
  async fetch(request, env) {
    const path = new URL(request.url).pathname;
    if (request.method === 'GET' && path === '/health') {
      return json({ service: SERVICE, status: 'ok', configured: Boolean(env.OPENAI_API_KEY && env.BACKEND_ACCESS_TOKEN) });
    }
    if (path !== '/v1/text') return json({ error: 'Not found' }, 404);
    if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
    if (!authorized(request, env.BACKEND_ACCESS_TOKEN)) return json({ error: 'Unauthorized' }, 401);
    if (!env.OPENAI_API_KEY) return json({ error: 'AI provider is not configured' }, 503);
    if (!request.headers.get('Content-Type')?.toLowerCase().startsWith('application/json')) {
      return json({ error: 'Expected application/json' }, 415);
    }
    const length = Number(request.headers.get('Content-Length') || 0);
    if (length > 24000) return json({ error: 'Request too large' }, 413);
    let body;
    try {
      const raw = await request.text();
      if (raw.length > 12000) return json({ error: 'Request too large' }, 413);
      body = JSON.parse(raw);
    } catch { return json({ error: 'Invalid JSON' }, 400); }
    const input = body?.text;
    if (typeof input !== 'string' || !input.trim() || input.length > MAX_CHARS) {
      return json({ error: 'text must contain 1–6000 characters' }, 400);
    }
    try {
      const response = await fetch('https://api.openai.com/v1/responses', {
        method: 'POST',
        headers: {
          Authorization: 'Bearer ' + env.OPENAI_API_KEY,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: 'gpt-4.1-mini',
          instructions: INSTRUCTION,
          input: input,
          max_output_tokens: MAX_OUTPUT_TOKENS,
          store: false,
        }),
        signal: AbortSignal.timeout(25000),
      });
      if (!response.ok) return json({ error: 'AI provider request failed', upstreamStatus: response.status }, 502);
      const data = await response.json();
      const output = (data.output || []).flatMap(item => item.content || [])
        .filter(part => part.type === 'output_text').map(part => part.text).join('');
      if (!output) return json({ error: 'AI provider returned no text' }, 502);
      return json({ text: output });
    } catch {
      return json({ error: 'AI request unavailable' }, 502);
    }
  },
};
