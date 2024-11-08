import { getOwner } from "@ember/owner";
import { clearRender, render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import CoreFabricators from "discourse/lib/fabricators";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Discourse Chat | Component | chat-message", function (hooks) {
  setupRenderingTest(hooks);

  const template = hbs`
    <ChatMessage @message={{this.message}} />
  `;

  test("Message with edits", async function (assert) {
    this.message = new ChatFabricators(getOwner(this)).message({
      edited: true,
    });
    await render(template);

    assert.true(exists(".chat-message-edited"), "has the correct css class");
  });

  test("Deleted message", async function (assert) {
    this.message = new ChatFabricators(getOwner(this)).message({
      user: this.currentUser,
      deleted_at: moment(),
    });
    await render(template);

    assert.true(
      exists(".chat-message-text.-deleted .chat-message-expand"),
      "has the correct css class and expand button within"
    );
  });

  test("Hidden message", async function (assert) {
    this.message = new ChatFabricators(getOwner(this)).message({
      hidden: true,
    });
    await render(template);

    assert.true(
      exists(".chat-message-text.-hidden .chat-message-expand"),
      "has the correct css class and expand button within"
    );
  });

  test("Message by a bot", async function (assert) {
    this.message = new ChatFabricators(getOwner(this)).message({
      message: "what <mark>test</mark>",
      user: new CoreFabricators(getOwner(this)).user({ id: -10 }),
    });
    await this.message.cook();
    await render(template);

    assert.dom(".chat-message-container.is-bot").exists("has the bot class");
  });

  test("Message with mark html tag", async function (assert) {
    this.message = new ChatFabricators(getOwner(this)).message({
      message: "what <mark>test</mark>",
    });
    await this.message.cook();
    await render(template);

    assert.true(
      query(".chat-message-text")
        .innerHTML.trim()
        .includes("<p>what <mark>test</mark></p>")
    );
  });

  test("Message with reply", async function (assert) {
    this.message = new ChatFabricators(getOwner(this)).message({
      inReplyTo: new ChatFabricators(getOwner(this)).message(),
    });
    await render(template);

    assert.true(
      exists(".chat-message-container.has-reply"),
      "has the correct css class"
    );
  });

  test("Message with streaming", async function (assert) {
    // admin
    this.currentUser.admin = true;

    this.message = new ChatFabricators(getOwner(this)).message({
      inReplyTo: new ChatFabricators(getOwner(this)).message(),
      streaming: true,
    });
    await this.message.cook();
    await render(template);

    assert
      .dom(".stop-streaming-btn")
      .exists("when admin, it has the stop streaming button");

    await clearRender();

    // not admin - not replying to current user
    this.currentUser.admin = false;

    this.message = new ChatFabricators(getOwner(this)).message({
      inReplyTo: new ChatFabricators(getOwner(this)).message(),
      streaming: true,
    });
    await this.message.cook();
    await render(template);

    assert
      .dom(".stop-streaming-btn")
      .doesNotExist("when admin, it doesn't have the stop streaming button");

    await clearRender();

    // not admin - replying to current user
    this.currentUser.admin = false;

    this.message = new ChatFabricators(getOwner(this)).message({
      inReplyTo: new ChatFabricators(getOwner(this)).message({
        user: this.currentUser,
      }),
      streaming: true,
    });
    await this.message.cook();
    await render(template);

    assert
      .dom(".stop-streaming-btn")
      .exists(
        "when replying to current user, it has the stop streaming button"
      );
  });
});
