import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Topic - Admin Menu Anonymous Users", function () {
  test("Enter as a regular user", async function (assert) {
    await visit("/t/internationalization-localization/280");
    assert.dom("#topic").exists("the topic is rendered");
    assert
      .dom(".toggle-admin-menu")
      .doesNotExist("The admin menu button was not rendered");
  });
});

acceptance("Topic - Admin Menu", function (needs) {
  needs.user();
  test("Enter as a user with group moderator permissions", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false, trust_level: 1 });

    await visit("/t/topic-for-group-moderators/2480");
    assert.dom("#topic").exists("the topic is rendered");
    assert
      .dom(".toggle-admin-menu")
      .exists("The admin menu button was rendered");

    await click(".toggle-admin-menu");
    assert.dom(".topic-admin-delete").exists("the delete item is rendered");
  });

  test("Enter as a user with moderator and admin permissions", async function (assert) {
    updateCurrentUser({ moderator: true, admin: true, trust_level: 4 });

    await visit("/t/internationalization-localization/280");
    assert.dom("#topic").exists("the topic is rendered");
    assert
      .dom(".toggle-admin-menu")
      .exists("The admin menu button was rendered");
  });

  test("Button added using addTopicAdminMenuButton", async function (assert) {
    updateCurrentUser({ admin: true });
    this.set("actionCalled", false);

    withPluginApi("1.31.0", (api) => {
      api.addTopicAdminMenuButton(() => {
        return {
          className: "extra-button",
          icon: "heart",
          label: "yes_value",
          action: () => {
            this.set("actionCalled", true);
          },
        };
      });
    });

    await visit("/t/internationalization-localization/280");
    assert.dom("#topic").exists("the topic is rendered");
    await click(".toggle-admin-menu");
    assert
      .dom(".extra-button svg.d-icon-heart")
      .exists("The icon was rendered");
    assert
      .dom(".extra-button .d-button-label")
      .hasText(i18n("yes_value"), "The label was rendered");
    await click(".extra-button");
    assert.true(this.actionCalled, "The action was called");
  });
});
