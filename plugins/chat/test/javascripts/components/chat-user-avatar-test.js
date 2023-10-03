import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { render } from "@ember/test-helpers";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";

function containerSelector(user, options = {}) {
  let onlineSelector = ":not(.is-online)";
  if (options.online) {
    onlineSelector = ".is-online";
  }

  return `.chat-user-avatar${onlineSelector} .chat-user-avatar__container[data-user-card=${user.username}] .avatar[title=${user.username}]`;
}

module("Discourse Chat | Component | <Chat::UserAvatar />", function (hooks) {
  setupRenderingTest(hooks);

  test("user is not online", async function (assert) {
    this.user = fabricators.user();
    this.chat = { presenceChannel: { users: [] } };

    await render(
      hbs`<Chat::UserAvatar @chat={{this.chat}} @user={{this.user}} />`
    );

    assert.dom(containerSelector(this.user, { online: false })).exists();
  });

  test("user is online", async function (assert) {
    this.user = fabricators.user();
    this.chat = {
      presenceChannel: { users: [{ id: this.user.id }] },
    };

    await render(
      hbs`<Chat::UserAvatar @chat={{this.chat}} @user={{this.user}} />`
    );

    assert.dom(containerSelector(this.user, { online: true })).exists();
  });

  test("showPresence=false", async function (assert) {
    this.user = fabricators.user();
    this.chat = {
      presenceChannel: { users: [{ id: this.user.id }] },
    };

    await render(
      hbs`<Chat::UserAvatar @showPresence={{false}} @chat={{this.chat}} @user={{this.user}} />`
    );

    assert.dom(containerSelector(this.user, { online: false })).exists();
  });
});
