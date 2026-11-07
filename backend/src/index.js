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
      return json({ service: SERVICE, status: 'ok', configured: Boolean(env.OPENAI_API_KEY && typeof env.BACKEND_ACCESS_TOKEN === 'string' && env.BACKEND_ACCESS_TOKEN.length >= 32), version: '0.3.0', capabilities: ['transcribe', 'translate'] });
    }
    if (!['/v1/text', '/v1/transcribe'].includes(path)) return json({ error: 'Not found' }, 404);
    if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
    if (!authorized(request, env.BACKEND_ACCESS_TOKEN)) return json({ error: 'Unauthorized' }, 401);
    if (!env.OPENAI_API_KEY) return json({ error: 'AI provider is not configured' }, 503);
    if (path === '/v1/transcribe') return transcribe(request, env);
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
    const languages = { sq: 'standard Albanian', de: 'German', en: 'English', tr: 'Turkish', ar: 'Arabic' };
    const target = body.targetLanguage ?? 'sq';
    const operation = body.operation ?? 'translate';
    if (!Object.hasOwn(languages, target) || !['translate', 'explain'].includes(operation)) return json({error: 'Unsupported operation or language'}, 400);
    const instruction = operation === 'translate'
      ? `Translate into ${languages[target]}. Preserve all meaning, repetitions, terminology and line breaks. Return only the complete translation.`
      : `Explain the passage clearly in ${languages[target]}. Do not invent citations or facts.`;
    try {
      const response = await fetch('https://api.openai.com/v1/responses', {
        method: 'POST',
        headers: {
          Authorization: 'Bearer ' + env.OPENAI_API_KEY,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: 'gpt-4.1-mini',
          instructions: instruction,
          input: input,
          max_output_tokens: MAX_OUTPUT_TOKENS,
          store: false,
        }),
        signal: AbortSignal.timeout(25000),
      });
      if (!response.ok) return json({ error: 'AI provider request failed', upstreamStatus: response.status }, 502);
      const data = await response.json();
      if (data.status === 'incomplete') return json({ error: 'Text output exceeded limit; select a shorter passage' }, 422);
      const output = (data.output || []).flatMap(item => item.content || [])
        .filter(part => part.type === 'output_text').map(part => part.text).join('');
      if (!output) return json({ error: 'AI provider returned no text' }, 502);
      return json({ text: output });
    } catch {
      return json({ error: 'AI request unavailable' }, 502);
    }
  },
};


async function transcribe(request, env) {
  const limit = 24 * 1024 * 1024;
  if (!request.headers.get('Content-Type')?.startsWith('audio/mp4')) return json({error: 'Expected audio/mp4'}, 415);
  if (Number(request.headers.get('Content-Length') || 0) > limit) return json({error: 'Audio too large'}, 413);
  if (!request.body) return json({error: 'Audio missing'}, 400);
  const reader = request.body.getReader();
  const chunks = [];
  let total = 0;
  try {
    while (true) {
      const {done, value} = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > limit) { await reader.cancel(); return json({error: 'Audio too large'}, 413); }
      chunks.push(value);
    }
  } catch { return json({error: 'Audio upload failed'}, 400); }
  finally { reader.releaseLock(); }
  if (total === 0) return json({error: 'Audio missing'}, 400);
  const form = new FormData();
  form.append('file', new Blob(chunks, {type: 'audio/mp4'}), 'chunk.m4a');
  form.append('model', 'whisper-1');
  form.append('response_format', 'verbose_json');
  form.append('timestamp_granularities[]', 'segment');
  try {
    const response = await fetch('https://api.openai.com/v1/audio/transcriptions', {
      method: 'POST', headers: {Authorization: 'Bearer ' + env.OPENAI_API_KEY},
      body: form, signal: AbortSignal.timeout(120000),
    });
    if (!response.ok) return json({error: 'Transcription provider failed', upstreamStatus: response.status}, 502);
    const data = await response.json();
    if (!Array.isArray(data.segments)) return json({error: 'Missing timed transcription'}, 502);
    const segments = data.segments.filter(s =>
      Number.isFinite(s.start) && Number.isFinite(s.end) && s.start >= 0 && s.end > s.start &&
      typeof s.text === 'string' && s.text.trim() && !(s.no_speech_prob > 0.8)
    ).map(s => ({start: s.start, end: s.end, text: s.text.trim()}));
    return json({segments});
  } catch { return json({error: 'Transcription unavailable'}, 502); }
}
