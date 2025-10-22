import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Model | group", function (hooks) {
  setupTest(hooks);

  test("displayName", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const group = store.createRecord("group", {
      name: "test",
      display_name: "donkey",
    });

    assert.strictEqual(
      group.displayName,
      "donkey",
      "it should return the display name"
    );

    group.set("display_name", null);

    assert.strictEqual(
      group.displayName,
      "test",
      "it should return the group's name"
    );
  });
});
