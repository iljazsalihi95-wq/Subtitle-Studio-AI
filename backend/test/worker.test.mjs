import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import assert from 'node:assert/strict';
const source = await readFile(new URL('../src/index.js', import.meta.url), 'utf8');
const {default: worker} = await import('data:text/javascript;base64,' + Buffer.from(source).toString('base64'));
const env = {OPENAI_API_KEY: 'test-provider-key', BACKEND_ACCESS_TOKEN: 'a'.repeat(40)};
function request(body, token = env.BACKEND_ACCESS_TOKEN) {
  return new Request('https://worker.test/v1/text', {method:'POST', headers:{'Content-Type':'application/json', Authorization:'Bearer '+token}, body:JSON.stringify(body)});
}
test('rejects unauthorized access before contacting provider', async () => {
  assert.equal((await worker.fetch(request({text:'hello'}, 'wrong'), env)).status, 401);
  assert.equal((await worker.fetch(request({text:'hello'}), {})).status, 401);
});
test('validates size and target language', async () => {
  assert.equal((await worker.fetch(request({text:'x'.repeat(6001)}),env)).status,400);
  assert.equal((await worker.fetch(request({text:'hello',targetLanguage:'invalid'}),env)).status,400);
});
test('uses requested translation language and never returns incomplete output', async () => {
  const old = globalThis.fetch;
  try {
    globalThis.fetch = async (url, options) => {
      const body = JSON.parse(options.body);
      assert.match(body.instructions,/German/);
      assert.equal(body.store,false);
      return Response.json({status:'completed',output:[{content:[{type:'output_text',text:'Hallo'}]}]});
    };
    let response = await worker.fetch(request({text:'hello',operation:'translate',targetLanguage:'de'}),env);
    assert.equal(response.status,200); assert.equal((await response.json()).text,'Hallo');
    globalThis.fetch = async () => Response.json({status:'incomplete',output:[{content:[{type:'output_text',text:'partial'}]}]});
    response = await worker.fetch(request({text:'hello'}),env);
    assert.equal(response.status,422);
  } finally {globalThis.fetch=old;}
});

function audioRequest(token = env.BACKEND_ACCESS_TOKEN, bytes = new Uint8Array([1,2,3])) {
  return new Request('https://worker.test/v1/transcribe', {method:'POST',
    headers:{'Content-Type':'audio/mp4', Authorization:'Bearer '+token}, body:bytes});
}
test('transcription authenticates and validates audio uploads', async () => {
  assert.equal((await worker.fetch(audioRequest('wrong'),env)).status,401);
  assert.equal((await worker.fetch(audioRequest(undefined,new Uint8Array()),env)).status,400);
  assert.equal((await worker.fetch(new Request('https://worker.test/v1/transcribe',{method:'POST',
    headers:{Authorization:'Bearer '+env.BACKEND_ACCESS_TOKEN,'Content-Type':'application/json'},body:'{}'}),env)).status,415);
});
test('transcription forwards audio and returns timed source text without leaking provider details', async () => {
  const old = globalThis.fetch;
  try {
    globalThis.fetch = async (url, options) => {
      assert.equal(url,'https://api.openai.com/v1/audio/transcriptions');
      assert.equal(options.body.get('model'),'whisper-1');
      assert.equal(options.body.get('response_format'),'verbose_json');
      assert.equal(options.body.get('file').size,3);
      return Response.json({segments:[{start:0.5,end:2,text:' السلام عليكم '},
        {start:2,end:1,text:'invalid'},{start:3,end:4,text:'noise',no_speech_prob:0.99}]});
    };
    const response = await worker.fetch(audioRequest(),env);
    assert.equal(response.status,200);
    assert.deepEqual((await response.json()).segments,[{start:0.5,end:2,text:'السلام عليكم'}]);
    globalThis.fetch = async () => new Response('private provider detail',{status:403});
    const failed = await worker.fetch(audioRequest(),env);
    assert.equal(failed.status,502);
    assert.doesNotMatch(await failed.text(),/private provider detail/);
  } finally { globalThis.fetch=old; }
});
