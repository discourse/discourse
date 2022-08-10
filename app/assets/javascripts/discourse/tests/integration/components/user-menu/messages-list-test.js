import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists, query, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { render, settled } from "@ember/test-helpers";
import { NOTIFICATION_TYPES } from "discourse/tests/fixtures/concerns/notification-types";
import { hbs } from "ember-cli-htmlbars";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import I18n from "I18n";

module("Integration | Component | user-menu | messages-list", function (hooks) {
  setupRenderingTest(hooks);

  const template = hbs`<UserMenu::MessagesList/>`;

  test("renders notifications on top and messages on bottom", async function (assert) {
    await render(template);
    const items = queryAll("ul li");

    assert.strictEqual(items.length, 2);

    assert.ok(items[0].classList.contains("notification"));
    assert.ok(items[0].classList.contains("unread"));
    assert.ok(items[0].classList.contains("private-message"));

    assert.ok(items[1].classList.contains("message"));
  });

  test("show all link", async function (assert) {
    await render(template);
    const link = query(".panel-body-bottom .show-all");
    assert.ok(
      link.href.endsWith("/u/eviltrout/messages"),
      "links to the user's messages page"
    );
    assert.strictEqual(
      link.title,
      I18n.t("user_menu.view_all_messages"),
      "has a title"
    );
  });

  test("dismiss button", async function (assert) {
    this.currentUser.set("grouped_unread_high_priority_notifications", {
      [NOTIFICATION_TYPES.private_message]: 72,
    });
    await render(template);
    const dismiss = query(".panel-body-bottom .notifications-dismiss");
    assert.ok(
      dismiss,
      "dismiss button is shown if the user has unread private_message notifications"
    );
    assert.strictEqual(
      dismiss.title,
      I18n.t("user.dismiss_messages_tooltip"),
      "dismiss button has a title"
    );

    this.currentUser.set("grouped_unread_high_priority_notifications", {});
    await settled();

    assert.notOk(
      exists(".panel-body-bottom .notifications-dismiss"),
      "dismiss button is not shown if the user no unread private_message notifications"
    );
  });

  test("empty state (aka blank page syndrome)", async function (assert) {
    pretender.get("/u/eviltrout/user-menu-private-messages", () => {
      return response({ notifications: [], topics: [] });
    });
    await render(template);
    assert.strictEqual(
      query(".empty-state-title").textContent.trim(),
      I18n.t("user.no_messages_title"),
      "empty state title is shown"
    );
    assert.ok(
      exists(".empty-state-body svg.d-icon-envelope"),
      "icon is correctly rendered in the empty state body"
    );
    const emptyStateBodyLink = query(".empty-state-body a");
    assert.ok(
      emptyStateBodyLink.href.endsWith("/about"),
      "link inside empty state body is rendered"
    );
  });
});
