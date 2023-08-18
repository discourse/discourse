import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import sinon from "sinon";
import I18n from "I18n";

module("Discourse Chat | Component | chat-header-icon", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {});

  test("full page - never separated sidebar mode", async function (assert) {
    this.currentUser.user_option.chat_separate_sidebar_mode = "never";
    sinon
      .stub(this.owner.lookup("service:chat-state-manager"), "isFullPageActive")
      .value(true);

    await render(hbs`<Chat::Header::Icon />`);

    assert
      .dom(".icon.btn-flat")
      .hasAttribute("title", I18n.t("chat.title_capitalized"))
      .hasAttribute("href", "/chat");

    assert.dom(".d-icon-d-chat").exists();
  });

  test("full page - always separated mode", async function (assert) {
    this.currentUser.user_option.chat_separate_sidebar_mode = "always";
    sinon
      .stub(this.owner.lookup("service:chat-state-manager"), "isFullPageActive")
      .value(true);

    await render(hbs`<Chat::Header::Icon />`);

    assert
      .dom(".icon.btn-flat")
      .hasAttribute("title", I18n.t("sidebar.panels.forum.label"))
      .hasAttribute("href", "/latest");

    assert.dom(".d-icon-random").exists();
  });

  test("mobile", async function (assert) {
    this.site.mobileView = true;

    await render(hbs`<Chat::Header::Icon />`);

    assert
      .dom(".icon.btn-flat")
      .hasAttribute("title", I18n.t("chat.title_capitalized"))
      .hasAttribute("href", "/chat");

    assert.dom(".d-icon-d-chat").exists();
  });
});
