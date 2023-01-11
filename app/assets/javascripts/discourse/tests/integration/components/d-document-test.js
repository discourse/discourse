import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";

function getTitleCount() {
  const match = document.title.match(/^\((\d+)\)\s/);
  if (match) {
    return parseInt(match[1], 10);
  } else {
    return null;
  }
}

function triggerTitleUpdate(appEvents) {
  appEvents.trigger("notifications:changed", { forced: true });
}

module("Integration | Component | d-document", function (hooks) {
  setupRenderingTest(hooks);

  test("when experimental user menu is enabled", async function (assert) {
    const titleBefore = document.title;
    try {
      this.currentUser.redesigned_user_menu_enabled = true;
      this.currentUser.user_option.title_count_mode = "notifications";
      await render(hbs`<DDocument />`);
      assert.strictEqual(
        getTitleCount(),
        null,
        "title doesn't have a count initially"
      );

      this.currentUser.unread_high_priority_notifications = 1;
      this.currentUser.unread_notifications = 2;
      this.currentUser.all_unread_notifications_count = 4;
      this.currentUser.unseen_reviewable_count = 8;
      triggerTitleUpdate(this.currentUser.appEvents);

      assert.strictEqual(
        getTitleCount(),
        12,
        "count in the title is the sum of all_unread_notifications_count and unseen_reviewable_count"
      );
    } finally {
      document.title = titleBefore;
    }
  });

  test("when experimental user menu is disabled", async function (assert) {
    const titleBefore = document.title;
    try {
      this.currentUser.redesigned_user_menu_enabled = false;
      this.currentUser.user_option.title_count_mode = "notifications";
      await render(hbs`<DDocument />`);
      assert.strictEqual(
        getTitleCount(),
        null,
        "title doesn't have a count initially"
      );

      this.currentUser.unread_high_priority_notifications = 1;
      this.currentUser.unread_notifications = 2;
      this.currentUser.all_unread_notifications_count = 4;
      this.currentUser.unseen_reviewable_count = 8;
      triggerTitleUpdate(this.currentUser.appEvents);

      assert.strictEqual(
        getTitleCount(),
        3,
        "count in the title is the sum of unread_notifications and unread_high_priority_notifications"
      );
    } finally {
      document.title = titleBefore;
    }
  });
});
