import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";
import { render } from "@ember/test-helpers";
import { cloneJSON, deepMerge } from "discourse-common/lib/object";
import { hbs } from "ember-cli-htmlbars";
import PrivateMessagesFixture from "discourse/tests/fixtures/private-messages-fixtures";

function getMessage(overrides = {}) {
  const data = cloneJSON(
    PrivateMessagesFixture["/topics/private-messages/eviltrout.json"].topic_list
      .topics[0]
  );
  return deepMerge(data, overrides);
}

module("Integration | Component | user-menu | message-item", function (hooks) {
  setupRenderingTest(hooks);

  const template = hbs`<UserMenu::MessageItem @item={{this.message}}/>`;

  test("item description is the fancy title of the message", async function (assert) {
    this.set(
      "message",
      getMessage({ fancy_title: "This is a <b>safe</b> title!" })
    );
    await render(template);
    assert.strictEqual(
      query("li.message .item-description").textContent.trim(),
      "This is a safe title!"
    );
    assert.strictEqual(
      query("li.message .item-description b").textContent.trim(),
      "safe",
      "fancy title is not escaped"
    );
  });
});
