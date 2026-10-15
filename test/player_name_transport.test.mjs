import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const source = readFileSync(new URL('../multiplayer/client.js', import.meta.url), 'utf8');
for (const [name, expected] of [
  ['张伟', '张伟'], ['李娜', '李娜'], ['王昊', '王昊'], ['王𠮷', '王𠮷'],
  ['张'.repeat(24), '张'.repeat(24)],
  ['王'.repeat(22) + '𠮷尾', '王'.repeat(22) + '𠮷'],
  ['𠮷'.repeat(13), '𠮷'.repeat(12)],
  ['A'.repeat(23) + '𠮷尾', 'A'.repeat(23)],
]) {
  test(`browser player name preserves Unicode within the legacy transport cap: ${name}`, async () => {
    const saved = new Map();
    const window = { addEventListener() {}, removeEventListener() {}, localStorage: {
      getItem: key => saved.get(key) ?? null, setItem: (key, value) => saved.set(key, value), removeItem: key => saved.delete(key),
    } };
    runInNewContext(source, { window, setInterval() { return 1; }, clearInterval() {}, URL, URLSearchParams });
    const client = window.EmberpanMP;
    client.prepare = async () => {};
    client.preferenceKey = 'unicode-test';
    let submitted;
    client.open = auth => { submitted = JSON.parse(JSON.stringify(auth)); };
    await client.begin({ op: 'create', name });
    assert.equal(submitted.name, expected);
    assert.equal(saved.get('unicode-test:name'), expected);
    assert.ok(submitted.name.length <= 24);
    assert.ok(!/[\uD800-\uDBFF]$/u.test(submitted.name));
    client.dispose();
  });
}
