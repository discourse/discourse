import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service from "@ember/service";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import VoiceVoiceCanvas from "discourse/plugins/voice/discourse/components/voice/voice-canvas";

class VoiceWebrtcStub extends Service {
  @tracked localStream = null;
  @tracked remoteStreams = [];
  @tracked remoteScreenAudioStreams = [];
  attachCalls = [];

  @action
  attachStream(stream, element) {
    this.attachCalls.push({ stream, element });
  }
}

module("Integration | Component | voice/voice-canvas", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.owner.unregister("service:voice-webrtc");
    this.owner.register("service:voice-webrtc", VoiceWebrtcStub);
    this.voiceWebrtc = this.owner.lookup("service:voice-webrtc");
  });

  test("re-attaches a remote stream when the object changes but the id stays the same", async function (assert) {
    const firstStream = { id: "peer-stream" };
    const secondStream = { id: "peer-stream" };

    this.voiceWebrtc.remoteStreams = [firstStream];

    await render(<template><VoiceVoiceCanvas /></template>);

    assert.strictEqual(this.voiceWebrtc.attachCalls.length, 1);
    assert.strictEqual(this.voiceWebrtc.attachCalls[0].stream, firstStream);

    const element = this.voiceWebrtc.attachCalls[0].element;

    this.voiceWebrtc.remoteStreams = [secondStream];
    await settled();

    assert.strictEqual(this.voiceWebrtc.attachCalls.length, 2);
    assert.strictEqual(this.voiceWebrtc.attachCalls[1].stream, secondStream);
    assert.strictEqual(this.voiceWebrtc.attachCalls[1].element, element);
  });

  test("renders a dedicated sink for each remote screen audio stream", async function (assert) {
    const voiceStream = { id: "voice-stream" };
    const screenAudioStream = { id: "screen-audio-stream" };

    this.voiceWebrtc.remoteStreams = [voiceStream];

    await render(<template><VoiceVoiceCanvas /></template>);

    assert.strictEqual(this.voiceWebrtc.attachCalls.length, 1);

    this.voiceWebrtc.remoteScreenAudioStreams = [screenAudioStream];
    await settled();

    assert.strictEqual(this.voiceWebrtc.attachCalls.length, 2);
    assert.strictEqual(
      this.voiceWebrtc.attachCalls[1].stream,
      screenAudioStream
    );
    assert
      .dom(".voice-voice-canvas audio")
      .exists({ count: 2 }, "keeps the voice sink alongside the screen sink");
  });
});
