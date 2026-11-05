import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Live | Unit | Service | live-chat-drafts", function (hooks) {
  setupTest(hooks);

  test("retains room drafts independently and discards them when the linked channel changes", function (assert) {
    const drafts = this.owner.lookup("service:live-chat-drafts");
    const fabricators = new ChatFabricators(this.owner);
    const channel = fabricators.channel();
    const otherChannel = fabricators.channel();
    const draft = drafts.get(1, channel);
    draft.message = "still composing";

    assert.strictEqual(
      drafts.get(1, channel).message,
      "still composing",
      "reopening the same room preserves its draft"
    );
    assert.strictEqual(
      drafts.get(2, channel).message,
      "",
      "another room has its own draft"
    );
    assert.strictEqual(
      drafts.get(1, otherChannel).message,
      "",
      "relinking starts a separate draft"
    );
    assert.strictEqual(
      drafts.get(1, channel).message,
      "",
      "the old association's draft is discarded"
    );
  });
});
