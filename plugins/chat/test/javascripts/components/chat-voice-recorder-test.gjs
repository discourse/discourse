import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import ChatVoiceRecorder from "discourse/plugins/chat/discourse/components/chat-voice-recorder";

class FakeMediaRecorder {
  static isTypeSupported(mimeType) {
    return mimeType === "audio/webm;codecs=opus";
  }

  constructor(stream, options) {
    this.mimeType = options.mimeType;
    this.state = "inactive";
    this.stream = stream;
    FakeMediaRecorder.lastInstance = this;
  }

  start(timeslice) {
    this.state = "recording";
    this.timeslice = timeslice;
  }

  stop() {
    if (this.state === "inactive") {
      return;
    }

    this.state = "inactive";
    this.ondataavailable?.({
      data: new Blob([this.finalChunkContents ?? "voice"], {
        type: this.mimeType,
      }),
    });
    this.onstop?.();
  }

  emitChunk(contents) {
    this.ondataavailable?.({
      data: new Blob([contents], { type: this.mimeType }),
    });
  }
}

class FakeAudioContext {
  constructor() {
    this.close = sinon.stub().resolves();
    FakeAudioContext.lastInstance = this;
  }

  createAnalyser() {
    return {
      fftSize: 256,
      getByteTimeDomainData(buffer) {
        buffer.forEach((_, index) => {
          buffer[index] = index % 4 === 0 ? 192 : 128;
        });
      },
    };
  }

  createMediaStreamSource() {
    return { connect: sinon.stub(), disconnect: sinon.stub() };
  }

  resume() {
    return Promise.resolve();
  }
}

module("Component | ChatVoiceRecorder", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.originalMediaDevices = Object.getOwnPropertyDescriptor(
      navigator,
      "mediaDevices"
    );
    this.originalMediaRecorder = Object.getOwnPropertyDescriptor(
      window,
      "MediaRecorder"
    );
    this.originalAudioContext = Object.getOwnPropertyDescriptor(
      window,
      "AudioContext"
    );

    this.track = { stop: sinon.stub() };
    this.stream = { getTracks: () => [this.track] };
    this.getUserMedia = sinon.stub().resolves(this.stream);
    Object.defineProperty(navigator, "mediaDevices", {
      configurable: true,
      value: { getUserMedia: this.getUserMedia },
    });
    Object.defineProperty(window, "MediaRecorder", {
      configurable: true,
      value: FakeMediaRecorder,
    });
    Object.defineProperty(window, "AudioContext", {
      configurable: true,
      value: FakeAudioContext,
    });

    this.siteSettings.chat_voice_recording_enabled = true;
    this.siteSettings.authorized_extensions = "weba|m4a|ogg";
    FakeAudioContext.lastInstance = undefined;
    FakeMediaRecorder.lastInstance = undefined;
    this.onRecordingReady = sinon.stub();
    this.sendEnabled = false;
  });

  hooks.afterEach(function () {
    if (this.originalMediaDevices) {
      Object.defineProperty(
        navigator,
        "mediaDevices",
        this.originalMediaDevices
      );
    } else {
      delete navigator.mediaDevices;
    }

    if (this.originalMediaRecorder) {
      Object.defineProperty(
        window,
        "MediaRecorder",
        this.originalMediaRecorder
      );
    } else {
      delete window.MediaRecorder;
    }

    if (this.originalAudioContext) {
      Object.defineProperty(window, "AudioContext", this.originalAudioContext);
    } else {
      delete window.AudioContext;
    }
  });

  async function renderRecorder(context) {
    await render(
      <template>
        <ChatVoiceRecorder
          @canAttachUploads={{true}}
          @onRecordingReady={{context.onRecordingReady}}
          @sendEnabled={{context.sendEnabled}}
        >
          <span class="send-button">Send</span>
        </ChatVoiceRecorder>
      </template>
    );
  }

  test("shows the recorder only when the site setting and a compatible format are available", async function (assert) {
    this.siteSettings.chat_voice_recording_enabled = false;

    await renderRecorder(this);

    assert
      .dom(".chat-voice-recorder")
      .doesNotExist("the recorder is disabled by default");
    assert.dom(".send-button").exists("the send control is preserved");
  });

  test("starts and finishes a recording", async function (assert) {
    await renderRecorder(this);

    await click(".chat-voice-recorder__start");

    assert.true(this.getUserMedia.calledOnce, "microphone access is requested");
    assert
      .dom(".chat-voice-recorder.is-active")
      .exists("the active recording surface is shown");
    assert
      .dom(".chat-voice-recorder__duration")
      .hasText("0:00", "the elapsed time starts at zero");
    assert.strictEqual(
      FakeMediaRecorder.lastInstance.timeslice,
      1000,
      "the recorder emits bounded chunks"
    );

    this.set("sendEnabled", true);
    assert
      .dom(".chat-voice-recorder.is-active")
      .exists("typing while recording does not hide the recording controls");

    await click(".chat-voice-recorder__finish");

    assert.true(
      this.onRecordingReady.calledOnce,
      "the recording is handed to the uploader"
    );
    const file = this.onRecordingReady.firstCall.args[0];
    assert.true(file instanceof File, "the recording is packaged as a file");
    assert.true(
      file.name.endsWith(".weba"),
      "the filename matches the WebM audio container"
    );
    assert.strictEqual(
      file.type,
      "audio/webm;codecs=opus",
      "the MIME type is preserved"
    );
    const metadata = this.onRecordingReady.firstCall.args[1];
    assert.strictEqual(
      metadata.audio_waveform_version,
      1,
      "the waveform format is versioned"
    );
    assert.true(metadata.audio_duration_ms > 0, "the duration is captured");
    assert.strictEqual(
      window.atob(metadata.audio_waveform).length,
      40,
      "a bounded waveform is captured"
    );
    assert.true(this.track.stop.calledOnce, "the microphone track is released");
  });

  test("can cancel while microphone permission is pending", async function (assert) {
    let resolvePermission;
    this.getUserMedia = sinon.stub().returns(
      new Promise((resolve) => {
        resolvePermission = resolve;
      })
    );
    Object.defineProperty(navigator, "mediaDevices", {
      configurable: true,
      value: { getUserMedia: this.getUserMedia },
    });

    await renderRecorder(this);
    await click(".chat-voice-recorder__start");

    assert
      .dom(".chat-voice-recorder__start")
      .hasAttribute("aria-label", "Discard recording");

    await click(".chat-voice-recorder__start");
    resolvePermission(this.stream);
    await settled();

    assert.true(this.track.stop.calledOnce, "a late stream is released");
    assert
      .dom(".chat-voice-recorder__start")
      .hasAttribute("aria-label", "Record a voice message");
  });

  test("cleans up when recording cannot start", async function (assert) {
    const startStub = sinon
      .stub(FakeMediaRecorder.prototype, "start")
      .throws(new Error("Capture failed"));

    await renderRecorder(this);
    await click(".chat-voice-recorder__start");

    assert.true(this.track.stop.calledOnce, "the microphone track is released");
    assert.true(
      FakeAudioContext.lastInstance.close.calledOnce,
      "the waveform context is closed"
    );
    assert
      .dom(".chat-voice-recorder__start")
      .hasAttribute(
        "aria-label",
        "Record a voice message",
        "the recorder returns to its idle state"
      );

    startStub.restore();
  });

  test("cleans up when the recording format changes while permission is pending", async function (assert) {
    let resolvePermission;
    this.getUserMedia = sinon.stub().returns(
      new Promise((resolve) => {
        resolvePermission = resolve;
      })
    );
    Object.defineProperty(navigator, "mediaDevices", {
      configurable: true,
      value: { getUserMedia: this.getUserMedia },
    });

    await renderRecorder(this);
    await click(".chat-voice-recorder__start");

    this.siteSettings.authorized_extensions = "mp3";
    resolvePermission(this.stream);
    await settled();

    assert.true(this.track.stop.calledOnce, "the microphone track is released");
    assert.true(
      FakeAudioContext.lastInstance.close.calledOnce,
      "the waveform context is closed"
    );
  });

  test("ignores a stale permission request after starting another", async function (assert) {
    let rejectFirstPermission;
    let resolveSecondPermission;
    this.getUserMedia = sinon.stub();
    this.getUserMedia.onFirstCall().returns(
      new Promise((_, reject) => {
        rejectFirstPermission = reject;
      })
    );
    this.getUserMedia.onSecondCall().returns(
      new Promise((resolve) => {
        resolveSecondPermission = resolve;
      })
    );
    Object.defineProperty(navigator, "mediaDevices", {
      configurable: true,
      value: { getUserMedia: this.getUserMedia },
    });

    await renderRecorder(this);
    await click(".chat-voice-recorder__start");
    await click(".chat-voice-recorder__start");
    await click(".chat-voice-recorder__start");

    const error = new Error("Denied");
    error.name = "NotAllowedError";
    rejectFirstPermission(error);
    await settled();

    assert
      .dom(".chat-voice-recorder__start")
      .hasAttribute(
        "aria-label",
        "Discard recording",
        "the second permission request remains pending"
      );

    resolveSecondPermission(this.stream);
    await settled();

    assert
      .dom(".chat-voice-recorder.is-active")
      .exists("the second permission request starts recording");
  });

  test("stops when the attachment size limit is reached", async function (assert) {
    this.siteSettings.max_attachment_size_kb = 0.02;

    await renderRecorder(this);
    await click(".chat-voice-recorder__start");

    FakeMediaRecorder.lastInstance.emitChunk("recorded-voice");
    await settled();

    assert.true(
      this.onRecordingReady.calledOnce,
      "the bounded recording is handed to the uploader"
    );
    assert.true(
      this.onRecordingReady.firstCall.args[0].size <=
        this.siteSettings.max_attachment_size_kb * 1024,
      "the finalized file stays within the attachment limit"
    );
    assert
      .dom(".chat-voice-recorder.is-active")
      .doesNotExist("recording stops at the upload boundary");
  });

  test("reports an uploader handoff failure", async function (assert) {
    const toasts = this.owner.lookup("service:toasts");
    this.onRecordingReady.rejects(new Error("Upload unavailable"));

    await renderRecorder(this);
    await click(".chat-voice-recorder__start");
    await click(".chat-voice-recorder__finish");

    assert.strictEqual(
      toasts.activeToasts.at(-1)?.options.data.message,
      i18n("chat.voice_recorder.upload_failed"),
      "the failed handoff is explained"
    );
  });

  test("does not upload a container whose final chunk exceeds the limit", async function (assert) {
    const toasts = this.owner.lookup("service:toasts");
    this.siteSettings.max_attachment_size_kb = 0.02;

    await renderRecorder(this);
    await click(".chat-voice-recorder__start");

    FakeMediaRecorder.lastInstance.finalChunkContents =
      "oversized-final-container-metadata";
    FakeMediaRecorder.lastInstance.emitChunk("recorded-voice");
    await settled();

    assert.false(
      this.onRecordingReady.called,
      "a truncated audio container is never uploaded"
    );
    assert.strictEqual(
      toasts.activeToasts.at(-1)?.options.data.message,
      i18n("chat.voice_recorder.maximum_size_exceeded")
    );
  });

  test("switches from microphone to send when the composer has content", async function (assert) {
    await renderRecorder(this);

    assert
      .dom(".chat-voice-recorder__start")
      .exists("the empty composer offers voice recording");
    assert.dom(".send-button").doesNotExist();

    this.set("sendEnabled", true);

    assert.dom(".chat-voice-recorder").doesNotExist();
    assert
      .dom(".send-button")
      .exists("the send action replaces the microphone");
  });

  test("discards a recording without uploading it", async function (assert) {
    await renderRecorder(this);

    await click(".chat-voice-recorder__start");
    await click(".chat-voice-recorder__cancel");

    assert.false(
      this.onRecordingReady.called,
      "discarded audio is not uploaded"
    );
    assert.true(this.track.stop.calledOnce, "the microphone track is released");
    assert
      .dom(".chat-voice-recorder.is-active")
      .doesNotExist("the composer returns to its idle state");
  });

  test("keeps the microphone visible when an insecure origin blocks capture", async function (assert) {
    const originalSecureContext = Object.getOwnPropertyDescriptor(
      window,
      "isSecureContext"
    );
    const toasts = this.owner.lookup("service:toasts");

    Object.defineProperty(navigator, "mediaDevices", {
      configurable: true,
      value: undefined,
    });
    Object.defineProperty(window, "isSecureContext", {
      configurable: true,
      value: false,
    });

    try {
      await renderRecorder(this);

      assert
        .dom(".chat-voice-recorder__start")
        .exists("the primary recording action remains visible");

      await click(".chat-voice-recorder__start");

      assert.strictEqual(
        toasts.activeToasts.at(-1)?.options.data.message,
        i18n("chat.voice_recorder.secure_connection_required"),
        "the user is told how to make recording available"
      );
    } finally {
      if (originalSecureContext) {
        Object.defineProperty(window, "isSecureContext", originalSecureContext);
      } else {
        delete window.isSecureContext;
      }
    }
  });

  test("preserves the send control when no authorized recording format is available", async function (assert) {
    this.siteSettings.authorized_extensions = "mp3";

    await renderRecorder(this);

    assert
      .dom(".chat-voice-recorder")
      .doesNotExist("the recorder is not offered for an unusable format");
    assert.dom(".send-button").exists("the send control is preserved");
  });
});
