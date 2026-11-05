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
