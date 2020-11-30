import { exists, acceptance } from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Admin - Users Badges", function (needs) {
  needs.user();

  test("lists badges", async function (assert) {
    await visit("/admin/users/1/eviltrout/badges");

    assert.ok(exists(`span[data-badge-name="Badge 8"]`));
  });
});
