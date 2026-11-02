import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  pickMimeType,
  recordingFilename,
} from "discourse/plugins/live/discourse/lib/live/local-recorder";

module("Live | Unit | Lib | local-recorder", function (hooks) {
  setupTest(hooks);

  test("pickMimeType prefers MP4 and falls back to WebM", function (assert) {
    assert.strictEqual(
      pickMimeType(true, () => true),
      "video/mp4;codecs=avc1,opus"
    );
    assert.strictEqual(
      pickMimeType(true, (type) => type.startsWith("video/webm")),
      "video/webm;codecs=vp9,opus"
    );
    assert.strictEqual(
      pickMimeType(false, (type) => type.startsWith("audio/webm")),
      "audio/webm;codecs=opus"
    );
    assert.strictEqual(
      pickMimeType(false, () => false),
      undefined,
      "leaves the choice to the browser when nothing matches"
    );
  });

  test("recordingFilename stamps the local time and matches the container", function (assert) {
    const date = new Date(2026, 9, 28, 9, 5);

    assert.strictEqual(
      recordingFilename("standup", "video/mp4;codecs=avc1,opus", date),
      "standup-2026-10-28-0905.mp4"
    );
    assert.strictEqual(
      recordingFilename("standup", "audio/mp4", date),
      "standup-2026-10-28-0905.m4a"
    );
    assert.strictEqual(
      recordingFilename("standup", "audio/ogg;codecs=opus", date),
      "standup-2026-10-28-0905.ogg"
    );
    assert.strictEqual(
      recordingFilename("standup", "video/webm;codecs=vp9,opus", date),
      "standup-2026-10-28-0905.webm"
    );
  });
});
