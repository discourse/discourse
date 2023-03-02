import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import fabricators from "../helpers/fabricators";
import { render } from "@ember/test-helpers";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import MockPresenceChannel from "../helpers/mock-presence-channel";

function mockChat(context) {
  const mock = context.container.lookup("service:chat");
  mock.draftStore = {};
  mock.currentUser = context.currentUser;
  mock.presenceChannel = MockPresenceChannel.create();
  return mock;
}

module("Discourse Chat | Component | chat-live-pane", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.set("chat", mockChat(this));
    this.set("channel", fabricators.chatChannel());
  });

  test("Shows skeleton when loading", async function (assert) {
    pretender.get(`/chat/chat_channels.json`, () => response(this.channel));
    pretender.get(`/chat/:id/messages.json`, () =>
      response({ chat_messages: [], meta: { can_delete_self: true } })
    );

    await render(
      hbs`<ChatLivePane @loadingMorePast={{true}} @chat={{this.chat}} @chatChannel={{this.channel}} />`
    );

    assert.true(exists(".chat-skeleton"));

    await render(
      hbs`<ChatLivePane @loadingMoreFuture={{true}} @chat={{this.chat}} @chatChannel={{this.channel}} />`
    );

    assert.true(exists(".chat-skeleton"));
  });
});
