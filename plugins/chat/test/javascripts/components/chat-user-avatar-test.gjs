import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import CoreFabricators from "discourse/lib/fabricators";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function containerSelector(user, options = {}) {
  let onlineSelector = ":not(.is-online)";
  if (options.online) {
    onlineSelector = ".is-online";
  }

  return `.chat-user-avatar${onlineSelector} .chat-user-avatar__container[data-user-card=${user.username}] .avatar[title=${user.username}]`;
}

module("Discourse Chat | Component | <ChatUserAvatar />", function (hooks) {
  setupRenderingTest(hooks);

  test("when user is not online", async function (assert) {
    this.user = new CoreFabricators(getOwner(this)).user();
    this.chat = { presenceChannel: { users: [] } };

    await render(
      hbs`<ChatUserAvatar @chat={{this.chat}} @user={{this.user}} />`
    );

    assert.dom(containerSelector(this.user, { online: false })).exists();
  });

  test("user is online", async function (assert) {
    this.user = new CoreFabricators(getOwner(this)).user();
    this.chat = {
      presenceChannel: { users: [{ id: this.user.id }] },
    };

    await render(
      hbs`<ChatUserAvatar @chat={{this.chat}} @user={{this.user}} />`
    );

    assert.dom(containerSelector(this.user, { online: true })).exists();
  });

  test("@showPresence=false", async function (assert) {
    this.user = new CoreFabricators(getOwner(this)).user();
    this.chat = {
      presenceChannel: { users: [{ id: this.user.id }] },
    };

    await render(
      hbs`<ChatUserAvatar @showPresence={{false}} @chat={{this.chat}} @user={{this.user}} />`
    );

    assert.dom(containerSelector(this.user, { online: false })).exists();
  });

  test("@interactive=true", async function (assert) {
    this.user = new CoreFabricators(getOwner(this)).user();

    await render(
      hbs`<ChatUserAvatar @interactive={{false}}  @user={{this.user}} />`
    );

    assert.dom(".clickable").doesNotExist();
  });
});
