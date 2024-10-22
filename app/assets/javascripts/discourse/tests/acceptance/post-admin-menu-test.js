import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";

acceptance("Post - Admin Menu - Anonymous", function () {
  test("Enter as a anon user", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".show-more-actions");

    assert.ok(exists("#topic"), "The topic was rendered");
    assert
      .dom("#post_1 .post-controls .edit")
      .exists("The edit button was not rendered");
    assert
      .dom(".show-post-admin-menu")
      .doesNotExist("The wrench button was not rendered");
  });
});

acceptance("Post - Admin Menu - Authenticated", function (needs) {
  needs.user();
  test("Enter as a user with group moderator permissions", async function (assert) {
    await visit("/t/topic-for-group-moderators/2480");
    await click(".show-more-actions");
    await click(".show-post-admin-menu");

    assert
      .dom("#post_1 .post-controls .edit")
      .exists("The edit button was rendered");
    assert.ok(exists(".add-notice"), "The add notice button was rendered");
  });
});
