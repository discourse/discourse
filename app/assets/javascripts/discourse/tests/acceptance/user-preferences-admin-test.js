import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";

acceptance("User Preferences Admin", function (needs) {
  needs.user({ admin: true });

  test("Desktop user admin button", async function (assert) {
    await visit("/u/eviltrout");
    assert.ok(exists(".user-admin"), "desktop user admin nav button exists");
  });
});

acceptance("User Preferences Admin - Mobile", function (needs) {
  needs.user({ admin: true });
  needs.mobileView();

  test("Mobile user admin button", async function (assert) {
    await visit("/u/eviltrout");
    assert
      .dom(".user-nav__admin")
      .exists("mobile user admin nav button exists");
  });
});
