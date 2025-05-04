import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import CoreFabricators from "discourse/lib/fabricators";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatUserAvatar from "discourse/plugins/chat/discourse/components/chat-user-avatar";

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
    const self = this;

    this.user = new CoreFabricators(getOwner(this)).user();
    this.chat = { presenceChannel: { users: [] } };

    await render(
      <template>
        <ChatUserAvatar @chat={{self.chat}} @user={{self.user}} />
      </template>
    );

    assert.dom(containerSelector(this.user, { online: false })).exists();
  });

  test("user is online", async function (assert) {
    const self = this;

    this.user = new CoreFabricators(getOwner(this)).user();
    this.chat = {
      presenceChannel: { users: [{ id: this.user.id }] },
    };

    await render(
      <template>
        <ChatUserAvatar @chat={{self.chat}} @user={{self.user}} />
      </template>
    );

    assert.dom(containerSelector(this.user, { online: true })).exists();
  });

  test("@showPresence=false", async function (assert) {
    const self = this;

    this.user = new CoreFabricators(getOwner(this)).user();
    this.chat = {
      presenceChannel: { users: [{ id: this.user.id }] },
    };

    await render(
      <template>
        <ChatUserAvatar
          @showPresence={{false}}
          @chat={{self.chat}}
          @user={{self.user}}
        />
      </template>
    );

    assert.dom(containerSelector(this.user, { online: false })).exists();
  });

  test("@interactive=true", async function (assert) {
    const self = this;

    this.user = new CoreFabricators(getOwner(this)).user();

    await render(
      <template>
        <ChatUserAvatar @interactive={{false}} @user={{self.user}} />
      </template>
    );

    assert.dom(".clickable").doesNotExist();
  });
});
