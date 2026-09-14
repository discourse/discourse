import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Voice | Unit | Service | voice-rooms", function (hooks) {
  setupTest(hooks);

  test("room edits preserve user-specific state across shared updates", function (assert) {
    const service = this.owner.lookup("service:voice-rooms");
    const membership = { id: 1, role_name: "moderator" };
    service.upsertRoom({
      id: 1,
      slug: "watercooler",
      name: "watercooler",
      can_manage: true,
      can_invite: true,
      membership,
      livekit_enabled: true,
    });

    service.handleDirectoryEvent({
      type: "updated",
      room: { id: 1, slug: "watercooler", name: "Watercooler" },
    });

    const room = service.roomById(1);
    assert.strictEqual(room.name, "Watercooler", "the edited name is applied");
    assert.true(room.can_manage, "the room can still be edited");
    assert.true(room.can_invite, "invitation permissions are preserved");
    assert.deepEqual(room.membership, membership, "membership is preserved");
    assert.true(room.livekit_enabled, "manager-only settings are preserved");
  });

  test("user-scoped responses can revoke room permissions", function (assert) {
    const service = this.owner.lookup("service:voice-rooms");
    service.upsertRoom({
      id: 1,
      slug: "watercooler",
      can_manage: true,
      can_invite: true,
      membership: { id: 1, role_name: "moderator" },
    });

    service.upsertRoom({
      id: 1,
      slug: "watercooler",
      can_manage: false,
      can_invite: false,
      membership: null,
    });

    const room = service.roomById(1);
    assert.false(room.can_manage, "management permissions can be revoked");
    assert.false(room.can_invite, "invitation permissions can be revoked");
    assert.strictEqual(room.membership, null, "membership can be removed");
  });

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
