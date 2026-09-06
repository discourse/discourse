import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatNavbarPinnedMessagesButton from "discourse/plugins/chat/discourse/components/chat/navbar/pinned-messages-button";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Component | ChatNavbar | PinnedMessagesButton", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  hooks.beforeEach(function () {
    this.siteSettings.chat_pinned_messages = true;
    this.fabricators = new ChatFabricators(getOwner(this));
    this.chatStateManager = getOwner(this).lookup("service:chat-state-manager");
    this.channel = this.fabricators.channel();
    this.channel.pinnedMessagesCount = 1;
    // the button is only a way back to the pins panel once the bar is dismissed
    this.channel.pinsDismissedAboveId = 1;
  });

  test("shows the button when the pinned bar is dismissed", async function (assert) {
    await render(
      <template>
        <ChatNavbarPinnedMessagesButton @channel={{this.channel}} />
      </template>
    );

    assert
      .dom(".c-navbar__pinned-messages-btn")
      .exists("the pinned messages button is shown");
  });

  test("does not show the button when the drawer is collapsed", async function (assert) {
    this.chatStateManager.didCollapseDrawer();

    await render(
      <template>
        <ChatNavbarPinnedMessagesButton @channel={{this.channel}} />
      </template>
    );

    assert
      .dom(".c-navbar__pinned-messages-btn")
      .doesNotExist("the pinned messages button is hidden");
  });
});
