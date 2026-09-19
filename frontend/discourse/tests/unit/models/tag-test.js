import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Model | tag", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.store = getOwner(this).lookup("service:store");
  });

  test("totalCount when pm_count is not present", function (assert) {
    const tag = this.store.createRecord("tag", { count: 5 });
    assert.strictEqual(tag.totalCount, 5);
  });

  test("totalCount when pm_count is present", function (assert) {
    const tag = this.store.createRecord("tag", { count: 5, pm_count: 8 });
    assert.strictEqual(tag.totalCount, 13);
  });

  test("url encodes legacy tag names with periods without ids", function (assert) {
    const tag = this.store.createRecord("tag", { name: "node.js" });
    assert.strictEqual(tag.url, "/tag/node%2Ejs");
  });

  test("pmOnly", function (assert) {
    const tag = this.store.createRecord("tag", { pm_only: false });

    assert.false(tag.pmOnly);

    tag.set("pm_only", true);

    assert.true(tag.pmOnly);
  });
});
