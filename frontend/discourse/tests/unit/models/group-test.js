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

  test("asJSON extracts tag names when tags are objects", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const group = store.createRecord("group", { name: "test" });

    group.set("watching_tags", [
      { id: 1, name: "art", slug: "art" },
      { id: 2, name: "music", slug: "music" },
    ]);
    group.set("tracking_tags", ["books"]);
    group.set("muted_tags", []);

    const json = group.asJSON();

    assert.deepEqual(json.watching_tags, ["art", "music"]);
    assert.deepEqual(json.tracking_tags, ["books"]);
    assert.deepEqual(json.muted_tags, [""]);
  });
});
