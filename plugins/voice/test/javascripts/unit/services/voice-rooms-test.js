import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Voice | Unit | Service | voice-rooms", function (hooks) {
  setupTest(hooks);

  test("participant lists keep one canonical order across updates", function (assert) {
    const service = this.owner.lookup("service:voice-rooms");

    service.handleDirectoryEvent({
      type: "created",
      room: {
        id: 1,
        slug: "watercooler",
        active_participants: [
          { id: 3, username: "zoe" },
          { id: 1, username: "adam" },
        ],
      },
    });

    assert.deepEqual(
      service.roomById(1).active_participants.map((entry) => entry.username),
      ["adam", "zoe"],
      "directory payloads are normalized"
    );

    service.handleRoomBroadcast({
      room_id: 1,
      type: "participants",
      participants: [
        { id: 2, username: "Mia" },
        { id: 3, username: "zoe" },
        { id: 1, username: "adam" },
      ],
    });

    assert.deepEqual(
      service.roomById(1).active_participants.map((entry) => entry.username),
      ["adam", "Mia", "zoe"],
      "broadcasts arriving in arbitrary order are normalized"
    );

    service.addParticipant(1, { id: 4, username: "bea" });

    assert.deepEqual(
      service.roomById(1).active_participants.map((entry) => entry.username),
      ["adam", "bea", "Mia", "zoe"],
      "locally added participants slot into the canonical order"
    );
  });
});
