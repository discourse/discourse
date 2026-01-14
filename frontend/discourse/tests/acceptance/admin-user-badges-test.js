import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Admin - Users Badges", function (needs) {
  needs.user();

  test("lists badges", async function (assert) {
    await visit("/admin/users/1/eviltrout/badges");

    assert.dom(`span[data-badge-name="Badge 8"]`).exists();
  });
});
