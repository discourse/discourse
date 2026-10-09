import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import MenuItem from "discourse/components/user-menu/menu-item";
import UserMenuNotificationItem from "discourse/lib/user-menu/notification-item";
import Notification from "discourse/models/notification";
import { NOTIFICATION_TYPES } from "discourse/tests/fixtures/concerns/notification-types";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Notification | votes released", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    const notification = Notification.create({
      id: 11,
      user_id: 1,
      notification_type: NOTIFICATION_TYPES.votes_released,
      read: false,
      topic_id: 449,
      fancy_title: "Add dark mode",
      slug: "add-dark-mode",
      data: { message: "votes_released", title: "votes_released" },
    });

    this.item = new UserMenuNotificationItem({
      notification,
      currentUser: this.currentUser,
      siteSettings: this.siteSettings,
      site: this.site,
    });
  });

  test("says the vote was returned when vote limits are enabled", async function (assert) {
    this.siteSettings.topic_voting_enable_vote_limits = true;

    await render(<template><MenuItem @item={{this.item}} /></template>);

    assert.dom("li .item-label").hasText("Vote returned");
    assert.dom("li a").hasAttribute("title", "Vote returned");
    assert.dom("li a .d-icon-plus").exists();
  });

  test("says voting closed when vote limits are disabled", async function (assert) {
    this.siteSettings.topic_voting_enable_vote_limits = false;

    await render(<template><MenuItem @item={{this.item}} /></template>);

    assert.dom("li .item-label").hasText("Voting closed");
    assert.dom("li a").hasAttribute("title", "Voting closed");
    assert.dom("li a .d-icon-lock").exists();
  });
});
