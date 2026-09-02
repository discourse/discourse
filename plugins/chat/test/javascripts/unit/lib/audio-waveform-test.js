import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  encodeAudioWaveform,
  getVoiceMessageUpload,
  isSupportedAudioWaveform,
  normalizeAudioPeaks,
} from "discourse/plugins/chat/discourse/lib/audio-waveform";

module("Unit | Lib | audio-waveform", function (hooks) {
  setupTest(hooks);

  test("normalizes real amplitude differences", function (assert) {
    const waveform = normalizeAudioPeaks([0.05, 0.2, 1, 0.1], 4);

    assert.strictEqual(waveform.length, 4, "one height is returned per bar");
    assert.true(waveform[0] < waveform[1], "quieter audio is shorter");
    assert.strictEqual(waveform[2], 255, "the loudest section uses full range");
    assert.true(waveform[3] < waveform[2], "the final quiet section recedes");
  });

  test("preserves silence", function (assert) {
    const waveform = normalizeAudioPeaks([0, 0, 0, 0], 4);

    assert.deepEqual(waveform, [0, 0, 0, 0], "silence is not embellished");
  });

  test("encodes a bounded upload value", function (assert) {
    const encoded = encodeAudioWaveform([0.25, 0.5, 1]);

    assert.strictEqual(
      window.atob(encoded).length,
      40,
      "the encoded metadata always has one byte per player bar"
    );
  });

  test("recognizes only the supported waveform format", function (assert) {
    const waveform = Array.from({ length: 40 }, (_, index) => index * 6);

    assert.true(isSupportedAudioWaveform(waveform, 1));
    assert.false(isSupportedAudioWaveform(waveform, 2), "rejects new versions");
    assert.false(
      isSupportedAudioWaveform(waveform.slice(1), 1),
      "rejects incomplete samples"
    );
    assert.false(
      isSupportedAudioWaveform([...waveform.slice(0, -1), 256], 1),
      "rejects values outside the byte range"
    );
  });

  test("identifies a single recorded audio upload as a voice message", function (assert) {
    const waveform = Array.from({ length: 40 }, (_, index) => index * 6);
    const upload = {
      original_filename: "voice-message.m4a",
      audio_waveform: waveform,
      audio_waveform_version: 1,
    };

    assert.strictEqual(getVoiceMessageUpload([upload]), upload);
    assert.strictEqual(
      getVoiceMessageUpload([{ ...upload, original_filename: "photo.jpg" }]),
      undefined,
      "non-audio uploads are rejected"
    );
    assert.strictEqual(
      getVoiceMessageUpload([upload, upload]),
      undefined,
      "multi-upload messages are not treated as voice messages"
    );
  });
});
