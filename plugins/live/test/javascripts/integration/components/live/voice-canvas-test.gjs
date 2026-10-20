import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service from "@ember/service";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import LiveVoiceCanvas from "discourse/plugins/live/discourse/components/live/voice-canvas";

class LiveWebrtcStub extends Service {
  @tracked localStream = null;
  @tracked remoteStreams = [];
  @tracked remoteScreenAudioStreams = [];
  attachCalls = [];

  @action
  attachStream(stream, element) {
    this.attachCalls.push({ stream, element });
  }
}

module("Integration | Component | live/voice-canvas", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.owner.unregister("service:live-webrtc");
    this.owner.register("service:live-webrtc", LiveWebrtcStub);
    this.liveWebrtc = this.owner.lookup("service:live-webrtc");
  });

  test("re-attaches a remote stream when the object changes but the id stays the same", async function (assert) {
    const firstStream = { id: "peer-stream" };
    const secondStream = { id: "peer-stream" };

    this.liveWebrtc.remoteStreams = [firstStream];

    await render(<template><LiveVoiceCanvas /></template>);

    assert.strictEqual(this.liveWebrtc.attachCalls.length, 1);
    assert.strictEqual(this.liveWebrtc.attachCalls[0].stream, firstStream);

    const element = this.liveWebrtc.attachCalls[0].element;

    this.liveWebrtc.remoteStreams = [secondStream];
    await settled();

    assert.strictEqual(this.liveWebrtc.attachCalls.length, 2);
    assert.strictEqual(this.liveWebrtc.attachCalls[1].stream, secondStream);
    assert.strictEqual(this.liveWebrtc.attachCalls[1].element, element);
  });

  test("renders a dedicated sink for each remote screen audio stream", async function (assert) {
    const voiceStream = { id: "voice-stream" };
    const screenAudioStream = { id: "screen-audio-stream" };

    this.liveWebrtc.remoteStreams = [voiceStream];

    await render(<template><LiveVoiceCanvas /></template>);

    assert.strictEqual(this.liveWebrtc.attachCalls.length, 1);

    this.liveWebrtc.remoteScreenAudioStreams = [screenAudioStream];
    await settled();

    assert.strictEqual(this.liveWebrtc.attachCalls.length, 2);
    assert.strictEqual(
      this.liveWebrtc.attachCalls[1].stream,
      screenAudioStream
    );
    assert
      .dom(".live-voice-canvas audio")
      .exists({ count: 2 }, "keeps the live sink alongside the screen sink");
  });
});
