import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import ThemeSettings from "admin/models/theme-settings";

module("Unit | Model | theme", function (hooks) {
  setupTest(hooks);

  test("create munges settings property to ThemeSettings instances", function (assert) {
    const store = getOwner(this).lookup("service:store");

    const theme = store.createRecord("theme", {
      settings: [
        { id: 1, name: "setting1" },
        { id: 2, name: "setting2" },
      ],
    });

    assert.true(
      theme.settings[0] instanceof ThemeSettings,
      "is an instance of ThemeSettings"
    );

    assert.true(
      theme.settings[1] instanceof ThemeSettings,
      "is an instance of ThemeSettings"
    );
  });

  test("adds an upload correctly", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const theme = store.createRecord("theme");

    assert.strictEqual(theme.uploads.length, 0, "uploads are an empty array");

    theme.setField("common", "bob", "", 999, 2);
    let fields = theme.theme_fields;
    assert.strictEqual(fields.length, 1, "expecting 1 theme field");
    assert.strictEqual(
      fields[0].upload_id,
      999,
      "expecting upload id to be set"
    );
    assert.strictEqual(fields[0].type_id, 2, "expecting type id to be set");

    assert.strictEqual(theme.uploads.length, 1, "expecting an upload");
  });
});
