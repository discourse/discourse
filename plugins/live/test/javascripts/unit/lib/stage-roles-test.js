import { module, test } from "qunit";
import {
  isStageSpeaker,
  participantEntitledToMedia,
  remoteTrackAllowed,
  sortStageAudience,
} from "discourse/plugins/live/discourse/lib/live/stage-roles";

function room(participant) {
  return {
    room_type: "open",
    video_enabled: true,
    active_participants: [{ id: 2, role: "participant", ...participant }],
  };
}

const videoTrack = { kind: "video" };
const audioTrack = { kind: "audio" };

module("Live | Unit | Lib | stage-roles", function () {
  test("a mesh video track needs the sender's entitlement", function (assert) {
    const cases = [
      [{ is_video_on: true, can_publish_video: true }, true, "entitled camera"],
      [
        { is_video_on: true, can_publish_video: false },
        false,
        "camera without the entitlement",
      ],
      [
        { is_screen_sharing: true, can_screen_share: true },
        true,
        "entitled screen share",
      ],
      [
        { is_screen_sharing: true, can_screen_share: false },
        false,
        "screen share without the entitlement",
      ],
      [
        { can_publish_video: true },
        true,
        "an idle entitled sender, whose pre-negotiated track arrives before it publishes",
      ],
      [{}, false, "no entitlement at all"],
    ];

    for (const [participant, expected, label] of cases) {
      assert.strictEqual(
        remoteTrackAllowed(room(participant), 2, videoTrack, [], {
          mesh: true,
        }),
        expected,
        label
      );
    }
  });

  test("bare screen audio needs the screen entitlement specifically", function (assert) {
    assert.true(
      remoteTrackAllowed(room({ can_screen_share: true }), 2, audioTrack, [], {
        mesh: true,
      }),
      "an entitled screen sharer's content audio plays"
    );

    assert.false(
      remoteTrackAllowed(
        room({ is_video_on: true, can_publish_video: true }),
        2,
        audioTrack,
        [],
        { mesh: true }
      ),
      "a camera entitlement does not carry screen audio"
    );

    assert.true(
      remoteTrackAllowed(room({}), 2, audioTrack, [{ id: "mic-stream" }], {
        mesh: true,
      }),
      "mic audio, which arrives with a stream, is untouched by media entitlements"
    );
  });

  test("entitlements are not required off the mesh, where the SFU enforces them", function (assert) {
    assert.true(
      remoteTrackAllowed(room({ is_video_on: true }), 2, videoTrack, []),
      "a LiveKit subscription may land before the roster broadcast"
    );
  });

  test("the room's own media flag still overrides an entitled sender", function (assert) {
    const disabled = room({ is_video_on: true, can_publish_video: true });
    disabled.video_enabled = false;

    assert.false(
      remoteTrackAllowed(disabled, 2, videoTrack, [], { mesh: true }),
      "a room with media disabled plays no video"
    );
  });

  test("a stage listener publishes nothing, however entitled", function (assert) {
    const stage = room({
      role: "listener",
      is_video_on: true,
      can_publish_video: true,
    });
    stage.room_type = "stage";

    assert.false(
      remoteTrackAllowed(stage, 2, videoTrack, [], { mesh: true }),
      "the role gate applies before entitlements matter"
    );
  });

  test("participantEntitledToMedia answers for a missing participant", function (assert) {
    assert.false(participantEntitledToMedia(undefined));
    assert.false(participantEntitledToMedia(null, { screenOnly: true }));
  });

  test("isStageSpeaker identifies moderators and speakers", function (assert) {
    assert.true(isStageSpeaker({ role: "moderator" }));
    assert.true(isStageSpeaker({ role: "speaker" }));
    assert.false(isStageSpeaker({ role: "participant" }));
    assert.false(isStageSpeaker({}));
    assert.false(isStageSpeaker(null));
  });

  test("sortStageAudience prioritizes raised hands FIFO, then invitations", function (assert) {
    const sorted = sortStageAudience([
      { id: 1, username: "alice" },
      { id: 2, username: "bob", speak_invited_at: 500 },
      { id: 3, username: "cara", hand_raised_at: 300 },
      { id: 4, username: "dan", hand_raised_at: 100 },
    ]);

    assert.deepEqual(
      sorted.map((p) => p.id),
      [4, 3, 2, 1],
      "orders raised hands earliest-first, then invited, then remaining listeners"
    );
  });
});
