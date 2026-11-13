import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import MobileTabBar from "discourse/components/mobile-tab-bar";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import ChatRoutesChannels from "discourse/plugins/chat/discourse/components/chat/routes/channels";
import ChatFooter from "discourse/plugins/chat/discourse/components/chat-footer";

module("Integration | Component | ChatFooter", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  hooks.beforeEach(function () {
    forceMobile();
    this.siteSettings.mobile_footer_navigation = true;
    this.siteSettings.sidebar_user_navigation = true;
    this.siteSettings.enable_public_channels = true;
    this.siteSettings.chat_threads_enabled = false;
    this.currentUser.setProperties({
      admin: false,
      moderator: false,
      can_direct_message: false,
    });
    this.owner.lookup("service:chat").set("currentUser", this.currentUser);
    this.owner.lookup("service:chat-state-manager").hasPreloadedChannels = true;
    this.owner.lookup("service:chat-history").visit({ name: "chat.channels" });
  });

  test("omits the secondary navigation when Channels is the only view", async function (assert) {
    await render(
      <template>
        <MobileTabBar />
        <div class="main-chat-outlet">
          <ChatRoutesChannels />
          <ChatFooter />
        </div>
      </template>
    );

    assert
      .dom(".mobile-tab-bar")
      .exists("the primary navigation remains available");
    assert
      .dom(".c-footer")
      .doesNotExist("a single view does not occupy the secondary bar");
    assert
      .dom(".c-routes.--channels .c-navbar__title")
      .hasText(
        i18n("chat.chat_channels"),
        "the Channels heading remains available"
      );
    assert
      .dom(".c-routes.--channels .chat-channel-list-options-button")
      .exists("list options remain in the Channels header");
  });

  test("keeps view switching and options when direct messages are available", async function (assert) {
    this.currentUser.set("can_direct_message", true);

    await render(
      <template>
        <MobileTabBar />
        <ChatFooter />
      </template>
    );

    assert
      .dom(".mobile-tab-bar__views #c-footer-channels")
      .exists("Channels is available in the secondary bar");
    assert
      .dom(".mobile-tab-bar__views #c-footer-direct-messages")
      .exists("direct messages are available alongside Channels");
    assert
      .dom(".mobile-tab-bar__views .chat-channel-list-options-button")
      .exists("list options remain beside the view switcher");
  });
});
