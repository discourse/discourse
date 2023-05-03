import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("User Preferences Admin", function (needs) {
  needs.user({ admin: true });

  test("User admin button", async function (assert) {
    await visit("/u/eviltrout");
    assert.ok(exists(".user-admin"), "desktop user admin nav button exists");
  });
});

acceptance("User Preferences Admin - Mobile", function (needs) {
  needs.user({ admin: true });
  needs.mobileView();

  test("User admin button", async function (assert) {
    await visit("/u/eviltrout");
    assert.ok(
      exists(".user-nav__admin"),
      "mobile user admin nav button exists"
    );
  });
});
