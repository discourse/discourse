import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import { i18n } from "discourse-i18n";
import { NOISE_SUPPRESSION_MODES } from "../../lib/live/audio-processing.js";
import { rmsToPercent, sampleRms } from "../../lib/live/input-gate.js";
import {
  applyOutputDevice,
  audioConstraints,
  enumerateAudioDevices,
  outputSelectionSupported,
  SYSTEM_DEFAULT_DEVICE_ID,
} from "../../lib/live/media-devices.js";
import { prefetchEngineAssets } from "../../lib/live/noise-suppression.js";
import {
  engineForMode,
  noiseSuppressionModeLabel,
} from "../../lib/live/ns-engines.js";
import { STT_MODELS, sttModelLabel } from "../../lib/live/stt-models.js";

const METER_INTERVAL_MS = 50;

export default class LiveVoiceSettingsModal extends Component {
  @service liveWebrtc;

  @tracked inputDevices = [];
  @tracked outputDevices = [];
  @tracked level = 0;
  @tracked micError = false;
  @tracked testingOutput = false;

  #previewStream = null;
  #previewContext = null;
  #meterTimer = null;
  #onDeviceChange = () => this.refreshDevices();

  constructor() {
    super(...arguments);
    this.startPreview();
    // Someone opening voice settings may be about to enable suppression;
    // warming the model bytes makes that toggle near-instant.
    const engine = engineForMode(this.liveWebrtc.noiseSuppressionMode);
    if (engine) {
      prefetchEngineAssets(engine).catch(() => {});
    }
    navigator.mediaDevices?.addEventListener?.(
      "devicechange",
      this.#onDeviceChange
    );
  }

  willDestroy() {
    super.willDestroy(...arguments);
    navigator.mediaDevices?.removeEventListener?.(
      "devicechange",
      this.#onDeviceChange
    );
    this.#stopPreview();
  }

  get outputSupported() {
    return outputSelectionSupported();
  }

  get showOutputPrompt() {
    return (
      this.outputSupported &&
      this.outputDevices.length <= 1 &&
      !!navigator.mediaDevices?.selectAudioOutput
    );
  }

  get gateThreshold() {
    return this.liveWebrtc.gateThreshold;
  }

  get busy() {
    return this.liveWebrtc.noiseSuppressionState === "starting";
  }

  get noiseSuppressionModeOptions() {
    return NOISE_SUPPRESSION_MODES.map((mode) => ({
      id: mode,
      name: noiseSuppressionModeLabel(mode),
    }));
  }

  get sttModelOptions() {
    return Object.keys(STT_MODELS).map((model) => ({
      id: model,
      name: sttModelLabel(model),
    }));
  }

  get qualityOptions() {
    return this.liveWebrtc.allowedVoiceQualityTiers().map((tier) => ({
      id: tier,
      name: i18n(`live.quality.${tier}`),
    }));
  }

  get showQuality() {
    return this.qualityOptions.length > 1;
  }

  get gateOpen() {
    return this.gateThreshold === 0 || this.level >= this.gateThreshold;
  }

  get meterFillStyle() {
    return trustHTML(`width: ${Math.round(this.level)}%`);
  }

  get thresholdMarkerStyle() {
    return trustHTML(`left: ${this.gateThreshold}%`);
  }

  get subtitlesAvailable() {
    return this.liveWebrtc.subtitlesAvailable;
  }

  async startPreview() {
    this.#stopPreview();
    this.micError = false;

    let stream;
    try {
      stream = await navigator.mediaDevices.getUserMedia({
        audio: audioConstraints(this.liveWebrtc.inputDeviceId),
      });
    } catch {
      if (!this.isDestroying) {
        this.micError = true;
        this.level = 0;
      }
      return;
    }

    if (this.isDestroying) {
      stream.getTracks().forEach((track) => track.stop());
      return;
    }

    this.#previewStream = stream;

    try {
      const context = new AudioContext();
      if (context.state === "suspended") {
        context.resume().catch(() => {});
      }
      const source = context.createMediaStreamSource(stream);
      const analyser = context.createAnalyser();
      analyser.fftSize = 512;
      source.connect(analyser);
      this.#previewContext = context;

      const dataArray = new Uint8Array(analyser.frequencyBinCount);
      const sample = () => {
        this.level = rmsToPercent(sampleRms(analyser, dataArray));
        this.#meterTimer = setTimeout(sample, METER_INTERVAL_MS);
      };
      sample();
    } catch {
      this.micError = true;
    }

    await this.refreshDevices();
  }

  async refreshDevices() {
    const { inputs, outputs } = await enumerateAudioDevices();
    if (this.isDestroying) {
      return;
    }

    const defaultOption = {
      id: SYSTEM_DEFAULT_DEVICE_ID,
      name: i18n("live.devices.system_default"),
    };
    this.inputDevices = [defaultOption, ...inputs];
    this.outputDevices = [defaultOption, ...outputs];
  }

  @action
  async onInputChange(deviceId) {
    await this.liveWebrtc.setInputDevice(deviceId);
    await this.startPreview();
  }

  @action
  onOutputChange(deviceId) {
    this.liveWebrtc.setOutputDevice(deviceId);
  }

  @action
  async chooseOutputDevice() {
    try {
      const device = await navigator.mediaDevices.selectAudioOutput();
      this.liveWebrtc.setOutputDevice(device.deviceId);
      await this.refreshDevices();
    } catch {}
  }

  @action
  onThresholdChange(event) {
    this.liveWebrtc.setGateThreshold(parseInt(event.target.value, 10));
  }

  @action
  onNoiseSuppressionModeChange(mode) {
    if (this.busy) {
      return;
    }
    // Serialization and state live in the audio pipeline; "starting" flows
    // back through noiseSuppressionState.
    this.liveWebrtc.setNoiseSuppressionMode(mode);
  }

  @action
  async toggleEchoCancellation() {
    await this.liveWebrtc.setEchoCancellation(
      !this.liveWebrtc.echoCancellation
    );
    // Processing changes swap the capture out from under the level meter.
    await this.startPreview();
  }

  @action
  toggleSubtitles() {
    this.liveWebrtc.toggleSubtitles();
  }

  @action
  async toggleAutoGainControl() {
    await this.liveWebrtc.setAutoGainControl(!this.liveWebrtc.autoGainControl);
    await this.startPreview();
  }

  @action
  async playOutputTest() {
    if (this.testingOutput) {
      return;
    }
    this.testingOutput = true;

    try {
      const context = new AudioContext();
      const destination = context.createMediaStreamDestination();
      const now = context.currentTime;

      [523.25, 659.25].forEach((frequency, index) => {
        const oscillator = context.createOscillator();
        const gain = context.createGain();
        oscillator.frequency.value = frequency;
        const start = now + index * 0.15;
        gain.gain.setValueAtTime(0.2, start);
        gain.gain.exponentialRampToValueAtTime(0.001, start + 0.3);
        oscillator.connect(gain).connect(destination);
        oscillator.start(start);
        oscillator.stop(start + 0.3);
      });

      const element = new Audio();
      element.srcObject = destination.stream;
      applyOutputDevice(element, this.liveWebrtc.outputDeviceId);
      await element.play();

      setTimeout(() => {
        element.pause();
        element.srcObject = null;
        context.close().catch(() => {});
        if (!this.isDestroying) {
          this.testingOutput = false;
        }
      }, 700);
    } catch {
      this.testingOutput = false;
    }
  }

  #stopPreview() {
    if (this.#meterTimer) {
      clearTimeout(this.#meterTimer);
      this.#meterTimer = null;
    }

    if (this.#previewContext) {
      try {
        this.#previewContext.close();
      } catch {}
      this.#previewContext = null;
    }

    if (this.#previewStream) {
      this.#previewStream.getTracks().forEach((track) => track.stop());
      this.#previewStream = null;
    }
  }

  <template>
    <DModal
      class="live-voice-settings-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "live.voice_settings.title"}}
    >
      <:body>
        <div class="live-voice-settings">
          <div class="live-voice-settings__field">
            <label class="live-voice-settings__label">
              {{i18n "live.voice_settings.input_device"}}
            </label>
            <ComboBox
              class="live-voice-settings__input-select"
              @content={{this.inputDevices}}
              @onChange={{this.onInputChange}}
              @options={{hash none=false}}
              @value={{this.liveWebrtc.inputDeviceId}}
            />
          </div>

          {{#if this.outputSupported}}
            <div class="live-voice-settings__field">
              <label class="live-voice-settings__label">
                {{i18n "live.voice_settings.output_device"}}
              </label>
              <div class="live-voice-settings__output-row">
                {{#if this.showOutputPrompt}}
                  <DButton
                    class="live-voice-settings__choose-output-btn"
                    @action={{this.chooseOutputDevice}}
                    @icon="headphones"
                    @label="live.voice_settings.choose_output"
                  />
                {{else}}
                  <ComboBox
                    class="live-voice-settings__output-select"
                    @content={{this.outputDevices}}
                    @onChange={{this.onOutputChange}}
                    @options={{hash none=false}}
                    @value={{this.liveWebrtc.outputDeviceId}}
                  />
                {{/if}}
                <DButton
                  class="live-voice-settings__test-output-btn"
                  @action={{this.playOutputTest}}
                  @disabled={{this.testingOutput}}
                  @icon="play"
                  @label="live.voice_settings.test_output"
                />
              </div>
            </div>
          {{/if}}

          <div class="live-voice-settings__field">
            <label class="live-voice-settings__label">
              {{i18n "live.voice_settings.mic_test"}}
            </label>
            {{#if this.micError}}
              <p class="live-voice-settings__mic-error">
                {{i18n "live.voice_settings.mic_error"}}
              </p>
            {{else}}
              <div
                class="live-voice-settings__meter {{if this.gateOpen '--open'}}"
              >
                <span
                  class="live-voice-settings__meter-fill"
                  style={{this.meterFillStyle}}
                ></span>
                {{#if this.gateThreshold}}
                  <span
                    class="live-voice-settings__meter-threshold"
                    style={{this.thresholdMarkerStyle}}
                  ></span>
                {{/if}}
              </div>
              <p class="live-voice-settings__hint">
                {{i18n "live.voice_settings.mic_test_hint"}}
              </p>
            {{/if}}
          </div>

          <div class="live-voice-settings__field">
            <label
              class="live-voice-settings__label"
              for="live-voice-settings-sensitivity"
            >
              {{i18n "live.voice_settings.input_sensitivity"}}
            </label>
            <input
              class="live-voice-settings__sensitivity-slider"
              id="live-voice-settings-sensitivity"
              max="100"
              min="0"
              type="range"
              value={{this.gateThreshold}}
              {{on "input" this.onThresholdChange}}
            />
            <p class="live-voice-settings__hint">
              {{i18n "live.voice_settings.input_sensitivity_hint"}}
            </p>
          </div>

          <div class="live-voice-settings__field">
            <label class="live-voice-settings__label">
              {{i18n "live.voice_settings.noise_suppression"}}
            </label>
            <ComboBox
              class="live-voice-settings__noise-suppression-select"
              @content={{this.noiseSuppressionModeOptions}}
              @onChange={{this.onNoiseSuppressionModeChange}}
              @options={{hash none=false disabled=this.busy}}
              @value={{this.liveWebrtc.noiseSuppressionMode}}
            />
            <p class="live-voice-settings__hint">
              {{i18n "live.voice_settings.noise_suppression_hint"}}
            </p>
          </div>

          <div class="live-voice-settings__field">
            <DToggleSwitch
              class="live-voice-settings__echo-cancellation-toggle"
              @label="live.voice_settings.echo_cancellation"
              @state={{this.liveWebrtc.echoCancellation}}
              {{on "click" this.toggleEchoCancellation}}
            />
            <p class="live-voice-settings__hint">
              {{i18n "live.voice_settings.echo_cancellation_hint"}}
            </p>
          </div>

          <div class="live-voice-settings__field">
            <DToggleSwitch
              class="live-voice-settings__auto-gain-toggle"
              @label="live.voice_settings.auto_gain_control"
              @state={{this.liveWebrtc.autoGainControl}}
              {{on "click" this.toggleAutoGainControl}}
            />
            <p class="live-voice-settings__hint">
              {{i18n "live.voice_settings.auto_gain_control_hint"}}
            </p>
          </div>

          {{#if this.subtitlesAvailable}}
            <div class="live-voice-settings__field">
              <DToggleSwitch
                class="live-voice-settings__subtitles-toggle"
                @label="live.voice_settings.subtitles"
                @state={{this.liveWebrtc.subtitlesEnabled}}
                {{on "click" this.toggleSubtitles}}
              />
              <p class="live-voice-settings__hint">
                {{i18n "live.voice_settings.subtitles_hint"}}
              </p>
            </div>

            <div class="live-voice-settings__field">
              <label class="live-voice-settings__label">
                {{i18n "live.voice_settings.subtitles_model"}}
              </label>
              <ComboBox
                class="live-voice-settings__subtitles-model-select"
                @content={{this.sttModelOptions}}
                @onChange={{this.liveWebrtc.setSttModel}}
                @options={{hash none=false}}
                @value={{this.liveWebrtc.sttModel}}
              />
              <p class="live-voice-settings__hint">
                {{i18n "live.voice_settings.subtitles_model_hint"}}
              </p>
            </div>
          {{/if}}

          {{#if this.showQuality}}
            <div class="live-voice-settings__field">
              <label class="live-voice-settings__label">
                {{i18n "live.voice_settings.quality"}}
              </label>
              <ComboBox
                class="live-voice-settings__quality-select"
                @content={{this.qualityOptions}}
                @onChange={{this.liveWebrtc.setVoiceQuality}}
                @options={{hash none=false}}
                @value={{this.liveWebrtc.voiceQuality}}
              />
              <p class="live-voice-settings__hint">
                {{i18n "live.voice_settings.quality_hint"}}
              </p>
            </div>
          {{/if}}
        </div>
      </:body>
    </DModal>
  </template>
}
