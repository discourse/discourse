import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import {
  authorizedExtensions,
  authorizesAllExtensions,
} from "discourse/lib/uploads";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import Button from "discourse/plugins/chat/discourse/components/chat/composer/button";
import {
  AUDIO_WAVEFORM_VERSION,
  encodeAudioWaveform,
} from "discourse/plugins/chat/discourse/lib/audio-waveform";

const MAX_RECORDING_DURATION_MS = 10 * 60 * 1000;
const MEDIA_RECORDER_TIMESLICE_MS = 1000;
const TIMER_INTERVAL_MS = 250;
const WAVEFORM_SAMPLE_INTERVAL_MS = 50;
const RECORDING_FORMATS = [
  { extension: "weba", mimeType: "audio/webm;codecs=opus" },
  { extension: "m4a", mimeType: "audio/mp4" },
  { extension: "ogg", mimeType: "audio/ogg;codecs=opus" },
];

export default class ChatVoiceRecorder extends Component {
  @service a11y;
  @service currentUser;
  @service siteSettings;
  @service toasts;

  @tracked duration = 0;
  @tracked state = "idle";

  #audioContext;
  #chunks = [];
  #discardRecording = false;
  #destroyed = false;
  #fileExtension;
  #mediaRecorder;
  #recordedBytes = 0;
  #recordingTooLarge = false;
  #requestId = 0;
  #startedAt;
  #stoppedForSize = false;
  #stream;
  #timer;
  #waveformAnalyser;
  #waveformBuffer;
  #waveformPeaks = [];
  #waveformSource;
  #waveformTimer;

  willDestroy() {
    super.willDestroy(...arguments);
    this.#destroyed = true;
    this.#discardRecording = true;
    this.#destroyCapture();
  }

  get canOfferRecording() {
    return (
      this.siteSettings.chat_voice_recording_enabled &&
      this.args.canAttachUploads &&
      !this.args.disabled &&
      this.recordingFormat
    );
  }

  get canRecord() {
    return this.canOfferRecording && navigator.mediaDevices?.getUserMedia;
  }

  get durationLabel() {
    const totalSeconds = Math.floor(this.duration / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes}:${seconds.toString().padStart(2, "0")}`;
  }

  get isActive() {
    return this.state === "recording" || this.state === "stopping";
  }

  get isRequesting() {
    return this.state === "requesting";
  }

  get isStopping() {
    return this.state === "stopping";
  }

  get requestLabel() {
    return this.isRequesting
      ? i18n("chat.voice_recorder.cancel")
      : i18n("chat.voice_recorder.start");
  }

  get recordingFormat() {
    const MediaRecorder = window.MediaRecorder;
    if (!MediaRecorder?.isTypeSupported) {
      return;
    }

    const staff = !!this.currentUser?.staff;
    const allExtensionsAuthorized = authorizesAllExtensions(
      staff,
      this.siteSettings
    );
    const extensions = authorizedExtensions(staff, this.siteSettings);

    return RECORDING_FORMATS.find(
      ({ extension, mimeType }) =>
        (allExtensionsAuthorized || extensions.includes(extension)) &&
        MediaRecorder.isTypeSupported(mimeType)
    );
  }

  get shouldDisplay() {
    return (
      this.isActive ||
      this.isRequesting ||
      (this.canOfferRecording && !this.args.sendEnabled)
    );
  }

  @action
  cancelRecording() {
    if (this.state !== "recording") {
      return;
    }

    this.#discardRecording = true;
    this.#stopRecording();
    this.a11y.announce(i18n("chat.voice_recorder.cancelled"), "polite");
  }

  @action
  finishRecording() {
    if (this.state !== "recording") {
      return;
    }

    this.#discardRecording = false;
    this.#stopRecording();
  }

  @action
  async startRecording() {
    if (!this.canOfferRecording || this.state !== "idle") {
      return;
    }

    if (!this.canRecord) {
      this.#showCaptureError();
      return;
    }

    this.#prepareWaveformContext();
    const requestId = ++this.#requestId;
    this.state = "requesting";

    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          autoGainControl: true,
          echoCancellation: true,
          noiseSuppression: true,
        },
      });

      if (
        this.#destroyed ||
        this.state !== "requesting" ||
        requestId !== this.#requestId
      ) {
        stream.getTracks().forEach((track) => track.stop());
        return;
      }

      this.#startCapture(stream);
    } catch (error) {
      if (
        this.#destroyed ||
        this.state !== "requesting" ||
        requestId !== this.#requestId
      ) {
        return;
      }

      this.state = "idle";
      this.#cleanupWaveform();
      this.#showCaptureError(error);
    }
  }

  @action
  toggleRecordingRequest() {
    if (this.isRequesting) {
      this.#requestId++;
      this.state = "idle";
      this.#cleanupWaveform();
      this.a11y.announce(i18n("chat.voice_recorder.cancelled"), "polite");
      return;
    }

    this.startRecording();
  }

  async #completeRecording(recorder) {
    const blob = new Blob(this.#chunks, {
      type: recorder.mimeType || this.recordingFormat?.mimeType,
    });
    const discardRecording = this.#discardRecording;
    const recordingTooLarge = this.#recordingTooLarge;
    const stoppedForSize = this.#stoppedForSize;
    const duration = Math.max(1, this.duration, Date.now() - this.#startedAt);
    const metadata = this.#audioMetadata(duration);

    this.#cleanupCapture();
    this.state = "idle";

    if (discardRecording) {
      return;
    }

    if (recordingTooLarge) {
      this.#showError("chat.voice_recorder.maximum_size_exceeded");
      return;
    }

    if (!blob.size) {
      this.#showError("chat.voice_recorder.empty");
      return;
    }

    const file = new File(
      [blob],
      `voice-message-${Date.now()}.${this.#fileExtension}`,
      { lastModified: Date.now(), type: blob.type }
    );

    try {
      if (stoppedForSize) {
        this.toasts.default({
          duration: 8000,
          data: {
            message: i18n("chat.voice_recorder.maximum_size_reached"),
          },
        });
      }

      await this.args.onRecordingReady(file, metadata);
      this.a11y.announce(i18n("chat.voice_recorder.uploading"), "polite");
    } catch {
      this.#showError("chat.voice_recorder.upload_failed");
    }
  }

  #cleanupCapture() {
    window.clearInterval(this.#timer);
    this.#timer = undefined;

    if (this.#mediaRecorder) {
      this.#mediaRecorder.ondataavailable = null;
      this.#mediaRecorder.onerror = null;
      this.#mediaRecorder.onstop = null;

      if (this.#mediaRecorder.state !== "inactive") {
        this.#mediaRecorder.stop();
      }
    }

    this.#stream?.getTracks().forEach((track) => track.stop());
    this.#stream = undefined;
    this.#mediaRecorder = undefined;
    this.#chunks = [];
    this.#recordedBytes = 0;
    this.#recordingTooLarge = false;
    this.#stoppedForSize = false;
    this.#cleanupWaveform();
    this.duration = 0;
  }

  #destroyCapture() {
    window.clearInterval(this.#timer);

    if (this.#mediaRecorder) {
      this.#mediaRecorder.ondataavailable = null;
      this.#mediaRecorder.onerror = null;
      this.#mediaRecorder.onstop = null;

      if (this.#mediaRecorder.state !== "inactive") {
        this.#mediaRecorder.stop();
      }
    }

    this.#stream?.getTracks().forEach((track) => track.stop());
    this.#timer = undefined;
    this.#stream = undefined;
    this.#mediaRecorder = undefined;
    this.#chunks = [];
    this.#recordedBytes = 0;
    this.#recordingTooLarge = false;
    this.#stoppedForSize = false;
    this.#cleanupWaveform();
  }

  #showCaptureError(error) {
    const permissionErrors = [
      "NotAllowedError",
      "PermissionDeniedError",
      "SecurityError",
    ];
    let key = "chat.voice_recorder.unavailable";

    if (window.isSecureContext === false) {
      key = "chat.voice_recorder.secure_connection_required";
    } else if (permissionErrors.includes(error?.name)) {
      key = "chat.voice_recorder.permission_denied";
    }

    this.#showError(key);
  }

  #showError(key) {
    this.toasts.error({
      duration: 8000,
      data: { message: i18n(key) },
    });
  }

  #startCapture(stream) {
    const format = this.recordingFormat;

    if (!format) {
      stream.getTracks().forEach((track) => track.stop());
      this.#cleanupWaveform();
      this.state = "idle";
      this.#showCaptureError();
      return;
    }

    this.#stream = stream;

    try {
      const recorder = new window.MediaRecorder(stream, {
        mimeType: format.mimeType,
      });

      this.#chunks = [];
      this.#discardRecording = false;
      this.#fileExtension = format.extension;
      this.#mediaRecorder = recorder;
      this.#recordedBytes = 0;
      this.#recordingTooLarge = false;
      this.#stoppedForSize = false;
      this.#startedAt = Date.now();
      this.#startWaveformCapture(stream);

      recorder.ondataavailable = (event) => {
        if (event.data?.size) {
          const chunkStored = this.#storeChunk(event.data);
          this.#recordingTooLarge ||= !chunkStored;

          if (
            this.state === "recording" &&
            (!chunkStored ||
              this.#recordedBytes + event.data.size >=
                this.siteSettings.max_attachment_size_kb * 1024)
          ) {
            this.#stoppedForSize = true;
            this.finishRecording();
          }
        }
      };
      recorder.onerror = (event) => {
        recorder.ondataavailable = null;
        recorder.onstop = null;
        this.#discardRecording = true;
        this.#cleanupCapture();
        this.state = "idle";
        this.#showCaptureError(event.error);
      };
      recorder.onstop = () => this.#completeRecording(recorder);

      recorder.start(MEDIA_RECORDER_TIMESLICE_MS);
      this.state = "recording";
      this.#timer = window.setInterval(
        () => this.#updateDuration(),
        TIMER_INTERVAL_MS
      );
      this.a11y.announce(i18n("chat.voice_recorder.recording"), "polite");
    } catch (error) {
      this.#cleanupCapture();
      this.state = "idle";
      this.#showCaptureError(error);
    }
  }

  #stopRecording() {
    this.state = "stopping";
    window.clearInterval(this.#timer);
    this.#timer = undefined;
    this.#mediaRecorder?.stop();
  }

  #storeChunk(chunk) {
    const maximumBytes = this.siteSettings.max_attachment_size_kb * 1024;
    if (this.#recordedBytes + chunk.size > maximumBytes) {
      return false;
    }

    this.#chunks.push(chunk);
    this.#recordedBytes += chunk.size;
    return true;
  }

  #updateDuration() {
    this.duration = Date.now() - this.#startedAt;

    if (this.duration >= MAX_RECORDING_DURATION_MS) {
      this.toasts.default({
        duration: 8000,
        data: {
          message: i18n("chat.voice_recorder.maximum_reached", {
            minutes: MAX_RECORDING_DURATION_MS / 60_000,
          }),
        },
      });
      this.finishRecording();
    }
  }

  #audioMetadata(duration) {
    const waveform = encodeAudioWaveform(this.#waveformPeaks);
    if (!waveform) {
      return;
    }

    return {
      audio_duration_ms: Math.round(duration),
      audio_waveform: waveform,
      audio_waveform_version: AUDIO_WAVEFORM_VERSION,
    };
  }

  #cleanupWaveform() {
    window.clearInterval(this.#waveformTimer);
    this.#waveformSource?.disconnect();

    const closePromise = this.#audioContext?.close?.();
    closePromise?.catch?.(() => {});

    this.#audioContext = undefined;
    this.#waveformAnalyser = undefined;
    this.#waveformBuffer = undefined;
    this.#waveformPeaks = [];
    this.#waveformSource = undefined;
    this.#waveformTimer = undefined;
  }

  #sampleWaveform() {
    this.#waveformAnalyser.getByteTimeDomainData(this.#waveformBuffer);
    let sumOfSquares = 0;

    for (const sample of this.#waveformBuffer) {
      const amplitude = (sample - 128) / 128;
      sumOfSquares += amplitude * amplitude;
    }

    this.#waveformPeaks.push(
      Math.sqrt(sumOfSquares / this.#waveformBuffer.length)
    );
  }

  #prepareWaveformContext() {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (!AudioContext) {
      return;
    }

    try {
      this.#audioContext ||= new AudioContext();
      this.#audioContext.resume?.().catch?.(() => {});
    } catch {
      this.#cleanupWaveform();
    }
  }

  #startWaveformCapture(stream) {
    this.#prepareWaveformContext();
    if (!this.#audioContext) {
      return;
    }

    try {
      this.#waveformAnalyser = this.#audioContext.createAnalyser();
      this.#waveformAnalyser.fftSize = 256;
      this.#waveformBuffer = new Uint8Array(this.#waveformAnalyser.fftSize);
      this.#waveformPeaks = [];
      this.#waveformSource = this.#audioContext.createMediaStreamSource(stream);
      this.#waveformSource.connect(this.#waveformAnalyser);
      this.#waveformTimer = window.setInterval(
        () => this.#sampleWaveform(),
        WAVEFORM_SAMPLE_INTERVAL_MS
      );
      this.#sampleWaveform();
    } catch {
      this.#cleanupWaveform();
    }
  }

  <template>
    {{#if this.shouldDisplay}}
      <div
        class={{dConcatClass
          "chat-voice-recorder"
          (if this.isActive "is-active")
        }}
      >
        {{#if this.isActive}}
          <Button
            aria-label={{i18n "chat.voice_recorder.cancel"}}
            class="chat-voice-recorder__cancel"
            disabled={{this.isStopping}}
            title={{i18n "chat.voice_recorder.cancel"}}
            @icon="trash-can"
            {{on "click" this.cancelRecording}}
          />

          <span class="chat-voice-recorder__status">
            <span
              aria-hidden="true"
              class="chat-voice-recorder__indicator"
            ></span>
            <span class="sr-only">{{i18n
                "chat.voice_recorder.recording"
              }}</span>
            <time class="chat-voice-recorder__duration">
              {{this.durationLabel}}
            </time>
          </span>

          <Button
            aria-label={{i18n "chat.voice_recorder.finish"}}
            class="chat-voice-recorder__finish"
            disabled={{this.isStopping}}
            title={{i18n "chat.voice_recorder.finish"}}
            @icon={{if this.isStopping "spinner" "circle-stop"}}
            {{on "click" this.finishRecording}}
          />
        {{else}}
          <Button
            aria-label={{this.requestLabel}}
            class="chat-voice-recorder__start"
            title={{this.requestLabel}}
            @icon={{if this.isRequesting "xmark" "microphone"}}
            {{on "click" this.toggleRecordingRequest}}
          />
        {{/if}}
      </div>
    {{else}}
      {{yield}}
    {{/if}}
  </template>
}
