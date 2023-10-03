import { render } from "@ember/test-helpers";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Discourse Chat | Component | chat-message", function (hooks) {
  setupRenderingTest(hooks);

  const template = hbs`
    <ChatMessage @message={{this.message}} />
  `;

  test("Message with edits", async function (assert) {
    this.message = fabricators.message({ edited: true });
    await render(template);

    assert.true(exists(".chat-message-edited"), "has the correct css class");
  });

  test("Deleted message", async function (assert) {
    this.message = fabricators.message({
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
    this.message = fabricators.message({ hidden: true });
    await render(template);

    assert.true(
      exists(".chat-message-text.-hidden .chat-message-expand"),
      "has the correct css class and expand button within"
    );
  });

  test("Message with reply", async function (assert) {
    this.message = fabricators.message({ inReplyTo: fabricators.message() });
    await render(template);

    assert.true(
      exists(".chat-message-container.has-reply"),
      "has the correct css class"
    );
  });
});
