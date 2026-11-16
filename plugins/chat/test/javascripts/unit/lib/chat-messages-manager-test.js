import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import ChatMessagesManager from "discourse/plugins/chat/discourse/lib/chat-messages-manager";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Unit | Lib | chat-messages-manager", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.fabricators = new ChatFabricators(getOwner(this));
    this.manager = new ChatMessagesManager(getOwner(this));
  });

  test("keeps staged messages after confirmed ones, in the order they were sent", function (assert) {
    const firstStaged = this.fabricators.message({
      id: "staged-1",
      staged: true,
      created_at: "2026-09-23T12:00:00.000Z",
    });
    const secondStaged = this.fabricators.message({
      id: "staged-2",
      staged: true,
      created_at: "2026-09-23T11:59:00.000Z",
    });
    const confirmed = this.fabricators.message({
      id: 10,
      created_at: "2026-09-23T12:00:10.000Z",
    });

    this.manager.addMessages([firstStaged]);
    this.manager.addMessages([secondStaged]);
    this.manager.addMessages([confirmed]);

    assert.deepEqual(
      this.manager.messages.map((message) => message.id),
      [10, "staged-1", "staged-2"],
      "staged messages ignore their local timestamps"
    );
  });

  test("orders confirmed messages created in the same second by id", function (assert) {
    const newer = this.fabricators.message({
      id: 51,
      created_at: "2026-09-23T12:00:00Z",
    });
    const older = this.fabricators.message({
      id: 50,
      created_at: "2026-09-23T12:00:00Z",
    });

    this.manager.addMessages([newer]);
    this.manager.addMessages([older]);

    assert.deepEqual(
      this.manager.messages.map((message) => message.id),
      [50, 51],
      "the lower id comes first"
    );
  });

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
