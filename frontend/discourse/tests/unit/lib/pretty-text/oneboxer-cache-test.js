import { setupTest } from "ember-qunit";
import {
  failedCache,
  localCache,
  lookupCache,
  normalize,
  resetFailedCache,
  resetLocalCache,
  setFailedCache,
  setLocalCache,
} from "pretty-text/oneboxer-cache";
import { module, test } from "qunit";

function oneboxNode(html) {
  const template = document.createElement("template");
  template.innerHTML = html;
  return template.content.firstChild;
}

module("Unit | Pretty Text | Oneboxer Cache", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    resetLocalCache();
    resetFailedCache();
  });

  test("normalize drops one trailing slash", function (assert) {
    assert.strictEqual(normalize("http://a.com/"), "http://a.com");
    assert.strictEqual(normalize("http://a.com//"), "http://a.com/");
    assert.strictEqual(normalize("http://a.com"), "http://a.com");
  });

  test("lookupCache returns the cached onebox markup", function (assert) {
    setLocalCache("http://a.com", oneboxNode("<aside>A</aside>"));

    assert.strictEqual(lookupCache("http://a.com"), "<aside>A</aside>");
    assert.strictEqual(
      lookupCache("http://a.com/"),
      "<aside>A</aside>",
      "normalizes the url before the lookup"
    );
    assert.strictEqual(lookupCache("http://b.com"), undefined);
  });

  test("resetLocalCache replaces the exported cache", function (assert) {
    setLocalCache("http://a.com", oneboxNode("<aside>A</aside>"));
    assert.true("http://a.com" in localCache);

    resetLocalCache();

    assert.deepEqual(localCache, {}, "the live binding sees the new cache");
    assert.strictEqual(lookupCache("http://a.com"), undefined);
  });

  test("setFailedCache and resetFailedCache track failed urls", function (assert) {
    setFailedCache("http://a.com", true);
    assert.true(failedCache["http://a.com"]);

    resetFailedCache();

    assert.deepEqual(failedCache, {}, "the live binding sees the new cache");
  });
});
