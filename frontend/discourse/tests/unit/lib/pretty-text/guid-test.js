import { setupTest } from "ember-qunit";
import guid from "pretty-text/guid";
import { module, test } from "qunit";

module("Unit | Pretty Text | Guid", function (hooks) {
  setupTest(hooks);

  test("returns a version 4 UUID", function (assert) {
    assert.true(
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(
        guid()
      )
    );
  });

  test("returns a different value each time", function (assert) {
    assert.notStrictEqual(guid(), guid());
  });
});
