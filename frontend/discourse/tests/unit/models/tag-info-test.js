import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Model | tag-info", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.store = getOwner(this).lookup("service:store");
  });

  test("store.find fetches tag info via /tag/:id/info.json", async function (assert) {
    const result = await this.store.find("tag-info", 123);

    assert.strictEqual(result.id, 123);
    assert.strictEqual(result.name, "123");
  });
});
