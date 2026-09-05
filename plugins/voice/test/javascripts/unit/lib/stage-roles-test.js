import { module, test } from "qunit";
import {
  participantMayPublishMedia,
  remoteTrackAllowed,
} from "discourse/plugins/voice/discourse/lib/voice/stage-roles";

function room(participant) {
  return {
    room_type: "open",
    video_enabled: true,
    active_participants: [{ id: 2, role: "participant", ...participant }],
  };
}

const videoTrack = { kind: "video" };
const audioTrack = { kind: "audio" };

module("Voice | Unit | Lib | stage-roles", function () {
  test("a mesh video track needs the sender's entitlement and published state", function (assert) {
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
        { is_video_on: true, can_screen_share: true },
        false,
        "camera under a screen-only entitlement",
      ],
      [{ can_publish_video: true }, false, "entitlement without publishing"],
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
      remoteTrackAllowed(
        room({ is_screen_sharing: true, can_screen_share: true }),
        2,
        audioTrack,
        [],
        { mesh: true }
      ),
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

  test("participantMayPublishMedia answers for a missing participant", function (assert) {
    assert.false(participantMayPublishMedia(undefined));
    assert.false(participantMayPublishMedia(null, { screenOnly: true }));
  });
});
