import { module, test } from "qunit";
import Theme from "admin/models/theme";

module("Unit | Model | theme");

test("can add an upload correctly", function (assert) {
  let theme = Theme.create();

  assert.strictEqual(
    theme.get("uploads.length"),
    0,
    "uploads should be an empty array"
  );

  theme.setField("common", "bob", "", 999, 2);
  let fields = theme.get("theme_fields");
  assert.strictEqual(fields.length, 1, "expecting 1 theme field");
  assert.strictEqual(fields[0].upload_id, 999, "expecting upload id to be set");
  assert.strictEqual(fields[0].type_id, 2, "expecting type id to be set");

  assert.strictEqual(theme.get("uploads.length"), 1, "expecting an upload");
});
