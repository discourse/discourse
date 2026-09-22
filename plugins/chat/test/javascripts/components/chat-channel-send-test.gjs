import { click, fillIn, find, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import ChatChannel from "discourse/plugins/chat/discourse/components/chat-channel";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Component | ChatChannel", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    forceMobile();
    this.currentUser.set("id", 1);

    pretender.get("/chat/api/channels/1/messages", () =>
      response({ messages: [], meta: {} })
    );
    pretender.get("/chat/api/me/channels", () =>
      response({ direct_message_channels: [], public_channels: [] })
    );
    pretender.post("/chat/api/channels/1/drafts", () => response({}));

    this.channel = new ChatFabricators(this.owner).channel({ id: 1 });
    this.channel.currentUserMembership = { following: true };
  });

  hooks.afterEach(function () {
    sinon.restore();
  });

  test("sends only once when tapped again while formatting the message", async function (assert) {
    pretender.post("/chat/1", () => {
      assert.step("send message");
      return response({ success: "OK", message_id: 99 });
    });

    await render(
      <template><ChatChannel @channel={{this.channel}} /></template>
    );
    await fillIn(".chat-composer__input", "Hello there");

    let finishCooking;
    const cooking = new Promise((resolve) => {
      finishCooking = resolve;
    });
    const draft = this.channel.draft;
    const cook = draft.cook.bind(draft);
    sinon.stub(draft, "cook").callsFake(async () => {
      await cooking;
      return cook();
    });

    const sendButton = find(".chat-composer .-send");
    sendButton.click();
    sendButton.click();
    await settled();

    assert
      .dom(".chat-composer .-send")
      .isDisabled("sending is disabled while formatting is pending");

    sendButton.click();
    await settled();
    finishCooking();
    await settled();

    assert.verifySteps(["send message"], "the draft is submitted only once");
    assert.dom(".chat-composer__input").hasValue("", "the draft is cleared");

    await fillIn(".chat-composer__input", "Another message");
    assert
      .dom(".chat-composer .-send")
      .isNotDisabled("sending is enabled again for the next message");
    await click(".chat-composer .-send");

    assert.verifySteps(["send message"], "the next message can be sent");
  });

  test("allows another message after sending fails", async function (assert) {
    let sendAttempts = 0;
    pretender.post("/chat/1", () => {
      sendAttempts += 1;
      return sendAttempts === 1
        ? response(500, {})
        : response({ success: "OK", message_id: 99 });
    });

    await render(
      <template><ChatChannel @channel={{this.channel}} /></template>
    );
    await fillIn(".chat-composer__input", "First message");
    await click(".chat-composer .-send");

    assert
      .dom(".chat-message-error__retry-btn")
      .exists("the failed message can be retried");

    await fillIn(".chat-composer__input", "Second message");
    assert
      .dom(".chat-composer .-send")
      .isNotDisabled("sending is enabled again after the failure");
    await click(".chat-composer .-send");

    assert.strictEqual(sendAttempts, 2, "the next message is submitted");
    assert.dom(".chat-composer__input").hasValue("", "the draft is cleared");
  });
});
