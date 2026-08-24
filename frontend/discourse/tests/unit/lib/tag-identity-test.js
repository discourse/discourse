import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { tagIdentifiers, tagPath } from "discourse/lib/tag-identity";

module("Unit | Utility | tag-identity", function (hooks) {
  setupTest(hooks);

  test("tagIdentifiers returns the slug and the name", function (assert) {
    assert.deepEqual(
      tagIdentifiers({
        id: 1,
        name: "strategic_access",
        slug: "strategic-access",
      }),
      ["strategic-access", "strategic_access"]
    );
  });

  test("tagIdentifiers never matches on the localized name", function (assert) {
    assert.deepEqual(
      tagIdentifiers({
        id: 1,
        name: "戦略",
        slug: "strategic-access",
        original_name: "strategic_access",
      }),
      ["strategic-access", "strategic_access"]
    );
  });

  test("tagIdentifiers deduplicates and drops blanks", function (assert) {
    assert.deepEqual(tagIdentifiers({ id: 1, name: "foo", slug: "foo" }), [
      "foo",
    ]);
    assert.deepEqual(tagIdentifiers({ id: 1, name: "foo", slug: "" }), ["foo"]);
  });

  test("tagPath uses the slug and the id", function (assert) {
    assert.strictEqual(
      tagPath({ id: 1, name: "strategic_access", slug: "strategic-access" }),
      "/tag/strategic-access/1"
    );
  });

  test("tagPath falls back to the id placeholder for unslugged tags", function (assert) {
    assert.strictEqual(
      tagPath({ id: 1, name: "サポート", slug: "" }),
      "/tag/1-tag/1"
    );
  });

  test("tagPath falls back to the name route without an id", function (assert) {
    assert.strictEqual(tagPath({ name: "Node.js" }), "/tag/node%2Ejs");
    assert.strictEqual(tagPath("Node.js"), "/tag/node%2Ejs");
  });
});
