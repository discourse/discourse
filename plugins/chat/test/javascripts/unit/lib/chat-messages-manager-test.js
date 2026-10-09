import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import ChatMessagesManager from "discourse/plugins/chat/discourse/lib/chat-messages-manager";

module("Unit | Lib | chat-messages-manager", function (hooks) {
  setupTest(hooks);

  test("finds the first message using the user's timezone", function (assert) {
    const manager = new ChatMessagesManager(getOwner(this));
    manager.messages = [
      { id: 1, createdAt: new Date("2026-09-27T21:30:00Z") },
      { id: 2, createdAt: new Date("2026-09-27T22:30:00Z") },
    ];

    const message = manager.findFirstMessageOfDay(
      new Date("2026-09-27T22:00:00Z"),
      "Europe/Madrid"
    );

    assert.strictEqual(message.id, 2);
  });
});
