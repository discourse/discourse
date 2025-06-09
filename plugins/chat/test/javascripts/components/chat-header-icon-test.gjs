import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import Icon from "discourse/plugins/chat/discourse/components/chat/header/icon";
import { HEADER_INDICATOR_PREFERENCE_ALL_NEW } from "discourse/plugins/chat/discourse/controllers/preferences-chat";

module("Discourse Chat | Component | chat-header-icon", function (hooks) {
  setupRenderingTest(hooks);

  test("full page - never separated sidebar mode", async function (assert) {
    this.currentUser.user_option.chat_separate_sidebar_mode = "never";
    sinon
      .stub(this.owner.lookup("service:chat-state-manager"), "isFullPageActive")
      .value(true);

    await render(<template><Icon /></template>);

    assert
      .dom(".icon.btn-flat")
      .hasAttribute("title", i18n("chat.title_capitalized"))
      .hasAttribute("href", "/chat");

    assert.dom(".d-icon-d-chat").exists();
  });

  test("full page - always separated mode", async function (assert) {
    this.currentUser.user_option.chat_separate_sidebar_mode = "always";
    sinon
      .stub(this.owner.lookup("service:chat-state-manager"), "isFullPageActive")
      .value(true);

    await render(<template><Icon /></template>);

    assert
      .dom(".icon.btn-flat")
      .hasAttribute("title", i18n("sidebar.panels.forum.label"))
      .hasAttribute("href", "/latest");

    assert.dom(".d-icon-shuffle").exists();
  });

  test("mobile", async function (assert) {
    forceMobile();

    await render(<template><Icon /></template>);

    assert
      .dom(".icon.btn-flat")
      .hasAttribute("title", i18n("chat.title_capitalized"))
      .hasAttribute("href", "/chat");

    assert.dom(".d-icon-d-chat").exists();
  });

  test("full page - with unread", async function (assert) {
    this.currentUser.user_option.chat_separate_sidebar_mode = "always";
    this.currentUser.user_option.chat_header_indicator_preference =
      HEADER_INDICATOR_PREFERENCE_ALL_NEW;

    sinon
      .stub(this.owner.lookup("service:chat-state-manager"), "isFullPageActive")
      .value(true);

    await render(<template><Icon @urgentCount={{1}} /></template>);

    assert
      .dom(".icon.btn-flat")
      .hasAttribute("title", i18n("sidebar.panels.forum.label"))
      .hasAttribute("href", "/latest");
    assert.dom(".d-icon-shuffle").exists();
    assert.dom(".chat-channel-unread-indicator__number").doesNotExist();
  });

  test("drawer - with unread", async function (assert) {
    this.currentUser.user_option.chat_separate_sidebar_mode = "always";
    this.currentUser.user_option.chat_header_indicator_preference =
      HEADER_INDICATOR_PREFERENCE_ALL_NEW;

    await render(<template><Icon @urgentCount={{1}} /></template>);

    assert
      .dom(".icon.btn-flat")
      .hasAttribute("title", i18n("sidebar.panels.chat.label"))
      .hasAttribute("href", "/chat");
    assert.dom(".d-icon-d-chat").exists();
    assert
      .dom(".chat-channel-unread-indicator__number")
      .exists()
      .containsText("1");
  });
});
