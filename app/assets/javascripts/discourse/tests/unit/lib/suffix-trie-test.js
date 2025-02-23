import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import SuffixTrie from "discourse/lib/suffix-trie";

module("Unit | SuffixTrie", function (hooks) {
  setupTest(hooks);

  test("SuffixTrie", function (assert) {
    const t = new SuffixTrie("/");
    t.add("a/b/c/d");
    t.add("b/a/c/d");
    t.add("c/b/a/d");
    t.add("d/c/b/a");

    t.add("a/b/c/d/");
    t.add("/a/b/c/d/");

    // Simple lookups
    assert.deepEqual(t.withSuffix("d"), ["a/b/c/d", "b/a/c/d", "c/b/a/d"]);
    assert.deepEqual(t.withSuffix("c/d"), ["a/b/c/d", "b/a/c/d"]);
    assert.deepEqual(t.withSuffix("b/c/d"), ["a/b/c/d"]);
    assert.deepEqual(t.withSuffix("a/b/c/d"), ["a/b/c/d"]);
    assert.deepEqual(t.withSuffix("b/a"), ["d/c/b/a"]);

    // With leading/trailing delimiters
    assert.deepEqual(t.withSuffix("c/d/"), ["a/b/c/d/", "/a/b/c/d/"]);
    assert.deepEqual(t.withSuffix("/a/b/c/d/"), ["/a/b/c/d/"]);

    // Limited lookups
    assert.deepEqual(t.withSuffix("d", 1), ["a/b/c/d"]);
    assert.deepEqual(t.withSuffix("d", 2), ["a/b/c/d", "b/a/c/d"]);
  });
});
