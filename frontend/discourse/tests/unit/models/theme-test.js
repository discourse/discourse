import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import ThemeSettings from "discourse/admin/models/theme-settings";

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

  test("exposes email header and footer targets and fields", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const theme = store.createRecord("theme", { theme_fields: [] });

    const targetNames = theme.targets.map((target) => target.name);
    assert.true(
      targetNames.includes("email_header"),
      "expecting an email_header target"
    );
    assert.true(
      targetNames.includes("email_footer"),
      "expecting an email_footer target"
    );

    assert.deepEqual(
      theme.fieldNames.email_header,
      ["email_header"],
      "expecting an email_header field"
    );
    assert.deepEqual(
      theme.fieldNames.email_footer,
      ["email_footer"],
      "expecting an email_footer field"
    );
  });
});
