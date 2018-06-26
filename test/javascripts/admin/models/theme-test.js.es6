import Theme from "admin/models/theme";

QUnit.module("model:theme");

QUnit.test("can add an upload correctly", function(assert) {
  let theme = Theme.create();

  assert.equal(
    theme.get("uploads.length"),
    0,
    "uploads should be an empty array"
  );

  theme.setField("common", "bob", "", 999, 2);
  let fields = theme.get("theme_fields");
  assert.equal(fields.length, 1, "expecting 1 theme field");
  assert.equal(fields[0].upload_id, 999, "expecting upload id to be set");
  assert.equal(fields[0].type_id, 2, "expecting type id to be set");

  assert.equal(theme.get("uploads.length"), 1, "expecting an upload");
});
