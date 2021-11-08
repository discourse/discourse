import { module, test } from "qunit";
import Group from "discourse/models/group";

module("Unit | Model | group", function () {
  test("displayName", function (assert) {
    const group = Group.create({ name: "test", display_name: "donkey" });

    assert.strictEqual(
      group.get("displayName"),
      "donkey",
      "it should return the display name"
    );

    group.set("display_name", null);

    assert.strictEqual(
      group.get("displayName"),
      "test",
      "it should return the group's name"
    );
  });
});
