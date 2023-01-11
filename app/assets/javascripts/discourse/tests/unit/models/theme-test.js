import { module, test } from "qunit";
import { setupTest } from "ember-qunit";
import { getOwner } from "discourse-common/lib/get-owner";

module("Unit | Model | theme", function (hooks) {
  setupTest(hooks);

  test("can add an upload correctly", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const theme = store.createRecord("theme");

    assert.strictEqual(
      theme.uploads.length,
      0,
      "uploads should be an empty array"
    );

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
