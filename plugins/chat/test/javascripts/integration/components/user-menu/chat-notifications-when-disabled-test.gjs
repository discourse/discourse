import { getOwner } from "@ember/owner";
import Service from "@ember/service";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import MenuItem from "discourse/components/user-menu/menu-item";
import UserMenuNotificationItem from "discourse/lib/user-menu/notification-item";
import Notification from "discourse/models/notification";
import { NOTIFICATION_TYPES } from "discourse/tests/fixtures/concerns/notification-types";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import chatUserMenu from "discourse/plugins/chat/discourse/initializers/chat-user-menu";

class ChatDisabledStub extends Service {
  userCanChat = false;
}

module(
  "Integration | Component | Chat | user-menu notifications when the user has chat disabled",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      const owner = getOwner(this);
      owner.unregister("service:chat");
      owner.register("service:chat", ChatDisabledStub);
      chatUserMenu.initialize(owner);
    });

    test("chat notifications are rendered instead of appearing blank", async function (assert) {
      const notification = Notification.create({
        id: 1,
        user_id: 1,
        notification_type: NOTIFICATION_TYPES.chat_invitation,
        read: false,
        high_priority: true,
        data: {
          chat_channel_id: 9,
          chat_channel_title: "Design",
          chat_channel_slug: "design",
          invited_by_username: "alice",
          chat_message_id: 5,
        },
      });

      const item = new UserMenuNotificationItem({
        notification,
        currentUser: this.currentUser,
        siteSettings: this.siteSettings,
        site: this.site,
      });

      await render(<template><MenuItem @item={{item}} /></template>);

      assert
        .dom("li.chat-invitation .item-label")
        .hasText("alice", "renders the inviter's username as the label");
      assert
        .dom("li.chat-invitation svg.d-icon-link")
        .exists("renders the chat invitation icon rather than a blank row");
      assert
        .dom("li.chat-invitation a")
        .hasAttribute(
          "href",
          /\/chat\/c\/design\/9\/5$/,
          "links to the channel"
        );
    });
  }
);
