import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, fillIn, render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";
import { Promise } from "rsvp";
import fabricators from "../helpers/fabricators";
import { module, test } from "qunit";

function mockChat(context, options = {}) {
  const mock = context.container.lookup("service:chat");
  mock.searchPossibleDirectMessageUsers = () => {
    return Promise.resolve({
      users: options.users || [{ username: "hawk" }, { username: "mark" }],
    });
  };
  mock.getDmChannelForUsernames = () => {
    return Promise.resolve({ chat_channel: fabricators.chatChannel() });
  };
  return mock;
}

module("Discourse Chat | Component | direct-message-creator", function (hooks) {
  setupRenderingTest(hooks);

  test("search", async function (assert) {
    this.set("chat", mockChat(this));
    this.set("channel", ChatChannel.createDirectMessageChannelDraft());

    await render(
      hbs`<DirectMessageCreator @channel={{this.channel}} @chat={{this.chat}} />`
    );

    await fillIn(".filter-usernames", "hawk");
    assert.true(exists("li.user[data-username='hawk']"));
  });

  test("select/deselect", async function (assert) {
    this.set("chat", mockChat(this));
    this.set("channel", ChatChannel.createDirectMessageChannelDraft());

    await render(
      hbs`<DirectMessageCreator @channel={{this.channel}} @chat={{this.chat}} />`
    );
    assert.false(exists(".selected-user"));

    await fillIn(".filter-usernames", "hawk");
    await click("li.user[data-username='hawk']");
    assert.true(exists(".selected-user"));

    await click(".selected-user");
    assert.false(exists(".selected-user"));
  });

  test("no search results", async function (assert) {
    this.set("chat", mockChat(this, { users: [] }));
    this.set("channel", ChatChannel.createDirectMessageChannelDraft());

    await render(
      hbs`<DirectMessageCreator @channel={{this.channel}} @chat={{this.chat}} />`
    );

    await fillIn(".filter-usernames", "bad cat");
    assert.true(exists(".no-results"));
  });

  test("loads user on first load", async function (assert) {
    this.set("chat", mockChat(this));
    this.set("channel", ChatChannel.createDirectMessageChannelDraft());

    await render(
      hbs`<DirectMessageCreator @channel={{this.channel}} @chat={{this.chat}} />`
    );

    assert.true(exists("li.user[data-username='hawk']"));
    assert.true(exists("li.user[data-username='mark']"));
  });

  test("do not load more users after selection", async function (assert) {
    this.set("chat", mockChat(this));
    this.set("channel", ChatChannel.createDirectMessageChannelDraft());

    await render(
      hbs`<DirectMessageCreator @channel={{this.channel}} @chat={{this.chat}} />`
    );

    await click("li.user[data-username='hawk']");
    assert.false(exists("li.user[data-username='mark']"));
  });

  test("apply is-focused to filter-area on focus input", async function (assert) {
    this.set("chat", mockChat(this));
    this.set("channel", ChatChannel.createDirectMessageChannelDraft());

    await render(
      hbs`<DirectMessageCreator @channel={{this.channel}} @chat={{this.chat}} /><button class="test-blur">blur</button>`
    );

    await click(".filter-usernames");
    assert.true(exists(".filter-area.is-focused"));

    await click(".test-blur");
    assert.false(exists(".filter-area.is-focused"));
  });

  test("state is reset on channel change", async function (assert) {
    this.set("chat", mockChat(this));
    this.set("channel", ChatChannel.createDirectMessageChannelDraft());

    await render(
      hbs`<DirectMessageCreator @channel={{this.channel}} @chat={{this.chat}} />`
    );

    await fillIn(".filter-usernames", "hawk");
    assert.strictEqual(query(".filter-usernames").value, "hawk");

    this.set("channel", fabricators.chatChannel());
    this.set("channel", ChatChannel.createDirectMessageChannelDraft());

    assert.strictEqual(query(".filter-usernames").value, "");
    assert.true(exists(".filter-area.is-focused"));
    assert.true(exists("li.user[data-username='hawk']"));
  });

  test("shows user status", async function (assert) {
    const userWithStatus = {
      username: "hawk",
      status: { emoji: "tooth", description: "off to dentist" },
    };
    const chat = mockChat(this, { users: [userWithStatus] });
    this.set("chat", chat);
    this.set("channel", ChatChannel.createDirectMessageChannelDraft());

    await render(
      hbs`<DirectMessageCreator @channel={{this.channel}} @chat={{this.chat}} />`
    );

    await fillIn(".filter-usernames", "hawk");
    assert.true(exists(".user-status-message"));
  });
});
