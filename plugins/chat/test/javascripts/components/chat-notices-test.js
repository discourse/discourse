import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender from "discourse/tests/helpers/create-pretender";
import { queryAll } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from 'discourse-i18n';
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Discourse Chat | Component | chat-notice", function (hooks) {
  setupRenderingTest(hooks);

  test("displays all notices for a channel", async function (assert) {
    this.channel = new ChatFabricators(getOwner(this)).channel();
    this.manager = this.container.lookup(
      "service:chat-channel-notices-manager"
    );
    this.manager.handleNotice({
      channel_id: this.channel.id,
      text_content: "hello",
    });
    this.manager.handleNotice({
      channel_id: this.channel.id,
      text_content: "goodbye",
    });
    this.manager.handleNotice({
      channel_id: this.channel.id + 1,
      text_content: "N/A",
    });

    await render(hbs`<ChatNotices @channel={{this.channel}} />`);

    const notices = queryAll(".chat-notices .chat-notices__notice");

    assert.strictEqual(notices.length, 2, "Two notices are rendered");

    assert.true(notices[0].innerText.includes("hello"));
    assert.true(notices[1].innerText.includes("goodbye"));
  });

  test("Notices can be cleared", async function (assert) {
    this.channel = new ChatFabricators(getOwner(this)).channel();
    this.manager = this.container.lookup(
      "service:chat-channel-notices-manager"
    );
    this.manager.handleNotice({
      channel_id: this.channel.id,
      text_content: "hello",
    });

    await render(hbs`<ChatNotices @channel={{this.channel}} />`);

    assert.strictEqual(
      queryAll(".chat-notices .chat-notices__notice").length,
      1,
      "Notice is present"
    );

    await click(".chat-notices__notice__clear");

    assert.strictEqual(
      queryAll(".chat-notices .chat-notices__notice").length,
      0,
      "Notice was cleared"
    );
  });
  test("MentionWithoutMembership notice renders", async function (assert) {
    this.channel = new ChatFabricators(getOwner(this)).channel();
    this.manager = this.container.lookup(
      "service:chat-channel-notices-manager"
    );
    const text = "Joffrey can't chat, hermano";
    this.manager.handleNotice({
      channel_id: this.channel.id,
      notice_type: "mention_without_membership",
      data: { user_ids: [1], message_id: 1, text },
    });

    await render(hbs`<ChatNotices @channel={{this.channel}} />`);

    assert.strictEqual(
      queryAll(
        ".chat-notices .chat-notices__notice .mention-without-membership-notice"
      ).length,
      1,
      "Notice is present"
    );

    assert.dom(".mention-without-membership-notice__body__text").hasText(text);
    assert
      .dom(".mention-without-membership-notice__body__link")
      .hasText(i18n("chat.mention_warning.invite"));

    pretender.post(`/chat/api/channels/${this.channel.id}/invites`, () => {
      return [200, { "Content-Type": "application/json" }, {}];
    });

    await click(".mention-without-membership-notice__body__link");

    // I would love to test that the invitation sent text is present here but
    // dismiss is called right away instead of waiting 3 seconds.. Not much we can
    // do about this - at least we are testing that nothing broke all the way through
    // clearing the notice
    assert.strictEqual(
      queryAll(
        ".chat-notices .chat-notices__notice .mention-without-membership-notice"
      ).length,
      0,
      "Notice has been cleared"
    );
  });
});
