import { render, settled } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { NOTIFICATION_TYPES } from "discourse/tests/fixtures/concerns/notification-types";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { query, queryAll } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

module(
  "Integration | Component | user-menu | bookmarks-list",
  function (hooks) {
    setupRenderingTest(hooks);

    const template = hbs`<UserMenu::BookmarksList/>`;

    test("renders notifications on top and bookmarks on bottom", async function (assert) {
      await render(template);
      const items = queryAll("ul li");

      assert.strictEqual(items.length, 2);

      assert.dom(items[0]).hasClass("notification");
      assert.dom(items[0]).hasClass("unread");
      assert.dom(items[0]).hasClass("bookmark-reminder");

      assert.dom(items[1]).hasClass("bookmark");
    });

    test("show all button for bookmark notifications", async function (assert) {
      await render(template);
      const link = query(".panel-body-bottom .show-all");
      assert.strictEqual(
        link.title,
        I18n.t("user_menu.view_all_bookmarks"),
        "has the correct title"
      );
    });

    test("dismiss button", async function (assert) {
      this.currentUser.set("grouped_unread_notifications", {
        [NOTIFICATION_TYPES.bookmark_reminder]: 72,
      });
      await render(template);
      const dismiss = query(".panel-body-bottom .notifications-dismiss");
      assert.ok(
        dismiss,
        "dismiss button is shown if the user has unread bookmark_reminder notifications"
      );
      assert.strictEqual(
        dismiss.title,
        I18n.t("user.dismiss_bookmarks_tooltip"),
        "dismiss button has a title"
      );

      this.currentUser.set("grouped_unread_notifications", {});
      await settled();

      assert
        .dom(".panel-body-bottom .notifications-dismiss")
        .doesNotExist(
          "dismiss button is not shown if the user no unread bookmark_reminder notifications"
        );
    });

    test("empty state (aka blank page syndrome)", async function (assert) {
      pretender.get("/u/eviltrout/user-menu-bookmarks", () => {
        return response({ notifications: [], bookmarks: [] });
      });
      await render(template);
      assert.strictEqual(
        query(".empty-state-title").textContent.trim(),
        I18n.t("user.no_bookmarks_title"),
        "empty state title is shown"
      );
      assert.strictEqual(
        query(".empty-state-body").textContent.trim(),
        I18n.t("user.no_bookmarks_body", { icon: "" }).trim(),
        "empty state body is shown"
      );
      assert
        .dom(".empty-state-body svg.d-icon-bookmark")
        .exists("icon is correctly rendered in the empty state body");
    });
  }
);
