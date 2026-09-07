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
import { NOISE_SUPPRESSION_MODES } from "../../lib/voice/audio-processing";
import { rmsToPercent, sampleRms } from "../../lib/voice/input-gate";
import {
  applyOutputDevice,
  audioConstraints,
  enumerateAudioDevices,
  outputSelectionSupported,
  SYSTEM_DEFAULT_DEVICE_ID,
} from "../../lib/voice/media-devices";
import { prefetchEngineAssets } from "../../lib/voice/noise-suppression";
import {
  engineForMode,
  noiseSuppressionModeLabel,
} from "../../lib/voice/ns-engines";

const METER_INTERVAL_MS = 50;

export default class VoiceVoiceSettingsModal extends Component {
  @service voiceWebrtc;

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
    const engine = engineForMode(this.voiceWebrtc.noiseSuppressionMode);
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
    return this.voiceWebrtc.gateThreshold;
  }

  get busy() {
    return this.voiceWebrtc.noiseSuppressionState === "starting";
  }

  get noiseSuppressionModeOptions() {
    return NOISE_SUPPRESSION_MODES.map((mode) => ({
      id: mode,
      name: noiseSuppressionModeLabel(mode),
    }));
  }

  get qualityOptions() {
    return this.voiceWebrtc.allowedVoiceQualityTiers().map((tier) => ({
      id: tier,
      name: i18n(`voice.quality.${tier}`),
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

  async startPreview() {
    this.#stopPreview();
    this.micError = false;

    let stream;
    try {
      stream = await navigator.mediaDevices.getUserMedia({
        audio: audioConstraints(this.voiceWebrtc.inputDeviceId),
      });
    } catch {
      if (!this.isDestroying && !this.isDestroyed) {
        this.micError = true;
        this.level = 0;
      }
      return;
    }

    if (this.isDestroying || this.isDestroyed) {
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
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    const defaultOption = {
      id: SYSTEM_DEFAULT_DEVICE_ID,
      name: i18n("voice.devices.system_default"),
    };
    this.inputDevices = [defaultOption, ...inputs];
    this.outputDevices = [defaultOption, ...outputs];
  }

  @action
  async onInputChange(deviceId) {
    await this.voiceWebrtc.setInputDevice(deviceId);
    await this.startPreview();
  }

  @action
  onOutputChange(deviceId) {
    this.voiceWebrtc.setOutputDevice(deviceId);
  }

  @action
  async chooseOutputDevice() {
    try {
      const device = await navigator.mediaDevices.selectAudioOutput();
      this.voiceWebrtc.setOutputDevice(device.deviceId);
      await this.refreshDevices();
    } catch {}
  }

  @action
  onThresholdChange(event) {
    this.voiceWebrtc.setGateThreshold(parseInt(event.target.value, 10));
  }

  @action
  onNoiseSuppressionModeChange(mode) {
    if (this.busy) {
      return;
    }
    // Serialization and state live in the audio pipeline; "starting" flows
    // back through noiseSuppressionState.
    this.voiceWebrtc.setNoiseSuppressionMode(mode);
  }

  @action
  async toggleEchoCancellation() {
    await this.voiceWebrtc.setEchoCancellation(
      !this.voiceWebrtc.echoCancellation
    );
    // Processing changes swap the capture out from under the level meter.
    await this.startPreview();
  }

  get subtitlesAvailable() {
    return this.voiceWebrtc.subtitlesAvailable;
  }

  @action
  toggleSubtitles() {
    this.voiceWebrtc.toggleSubtitles();
  }

  @action
  async toggleAutoGainControl() {
    await this.voiceWebrtc.setAutoGainControl(
      !this.voiceWebrtc.autoGainControl
    );
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
      applyOutputDevice(element, this.voiceWebrtc.outputDeviceId);
      await element.play();

      setTimeout(() => {
        element.pause();
        element.srcObject = null;
        context.close().catch(() => {});
        if (!this.isDestroying && !this.isDestroyed) {
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
      @closeModal={{@closeModal}}
      @title={{i18n "voice.voice_settings.title"}}
      class="voice-voice-settings-modal"
    >
      <:body>
        <div class="voice-voice-settings">
          <div class="voice-voice-settings__field">
            <label class="voice-voice-settings__label">
              {{i18n "voice.voice_settings.input_device"}}
            </label>
            <ComboBox
              @content={{this.inputDevices}}
              @value={{this.voiceWebrtc.inputDeviceId}}
              @onChange={{this.onInputChange}}
              @options={{hash none=false}}
              class="voice-voice-settings__input-select"
            />
          </div>

          {{#if this.outputSupported}}
            <div class="voice-voice-settings__field">
              <label class="voice-voice-settings__label">
                {{i18n "voice.voice_settings.output_device"}}
              </label>
              <div class="voice-voice-settings__output-row">
                {{#if this.showOutputPrompt}}
                  <DButton
                    @action={{this.chooseOutputDevice}}
                    @icon="headphones"
                    @label="voice.voice_settings.choose_output"
                    class="voice-voice-settings__choose-output-btn"
                  />
                {{else}}
                  <ComboBox
                    @content={{this.outputDevices}}
                    @value={{this.voiceWebrtc.outputDeviceId}}
                    @onChange={{this.onOutputChange}}
                    @options={{hash none=false}}
                    class="voice-voice-settings__output-select"
                  />
                {{/if}}
                <DButton
                  @action={{this.playOutputTest}}
                  @icon="play"
                  @label="voice.voice_settings.test_output"
                  @disabled={{this.testingOutput}}
                  class="voice-voice-settings__test-output-btn"
                />
              </div>
            </div>
          {{/if}}

          <div class="voice-voice-settings__field">
            <label class="voice-voice-settings__label">
              {{i18n "voice.voice_settings.mic_test"}}
            </label>
            {{#if this.micError}}
              <p class="voice-voice-settings__mic-error">
                {{i18n "voice.voice_settings.mic_error"}}
              </p>
            {{else}}
              <div
                class="voice-voice-settings__meter
                  {{if this.gateOpen '--open'}}"
              >
                <span
                  class="voice-voice-settings__meter-fill"
                  style={{this.meterFillStyle}}
                ></span>
                {{#if this.gateThreshold}}
                  <span
                    class="voice-voice-settings__meter-threshold"
                    style={{this.thresholdMarkerStyle}}
                  ></span>
                {{/if}}
              </div>
              <p class="voice-voice-settings__hint">
                {{i18n "voice.voice_settings.mic_test_hint"}}
              </p>
            {{/if}}
          </div>

          <div class="voice-voice-settings__field">
            <label
              class="voice-voice-settings__label"
              for="voice-voice-settings-sensitivity"
            >
              {{i18n "voice.voice_settings.input_sensitivity"}}
            </label>
            <input
              type="range"
              id="voice-voice-settings-sensitivity"
              min="0"
              max="100"
              value={{this.gateThreshold}}
              class="voice-voice-settings__sensitivity-slider"
              {{on "input" this.onThresholdChange}}
            />
            <p class="voice-voice-settings__hint">
              {{i18n "voice.voice_settings.input_sensitivity_hint"}}
            </p>
          </div>

          <div class="voice-voice-settings__field">
            <label class="voice-voice-settings__label">
              {{i18n "voice.voice_settings.noise_suppression"}}
            </label>
            <ComboBox
              @content={{this.noiseSuppressionModeOptions}}
              @value={{this.voiceWebrtc.noiseSuppressionMode}}
              @onChange={{this.onNoiseSuppressionModeChange}}
              @options={{hash none=false disabled=this.busy}}
              class="voice-voice-settings__noise-suppression-select"
            />
            <p class="voice-voice-settings__hint">
              {{i18n "voice.voice_settings.noise_suppression_hint"}}
            </p>
          </div>

          <div class="voice-voice-settings__field">
            <DToggleSwitch
              @state={{this.voiceWebrtc.echoCancellation}}
              @label="voice.voice_settings.echo_cancellation"
              class="voice-voice-settings__echo-cancellation-toggle"
              {{on "click" this.toggleEchoCancellation}}
            />
            <p class="voice-voice-settings__hint">
              {{i18n "voice.voice_settings.echo_cancellation_hint"}}
            </p>
          </div>

          <div class="voice-voice-settings__field">
            <DToggleSwitch
              @state={{this.voiceWebrtc.autoGainControl}}
              @label="voice.voice_settings.auto_gain_control"
              class="voice-voice-settings__auto-gain-toggle"
              {{on "click" this.toggleAutoGainControl}}
            />
            <p class="voice-voice-settings__hint">
              {{i18n "voice.voice_settings.auto_gain_control_hint"}}
            </p>
          </div>

          {{#if this.subtitlesAvailable}}
            <div class="voice-voice-settings__field">
              <DToggleSwitch
                @state={{this.voiceWebrtc.subtitlesEnabled}}
                @label="voice.voice_settings.subtitles"
                class="voice-voice-settings__subtitles-toggle"
                {{on "click" this.toggleSubtitles}}
              />
              <p class="voice-voice-settings__hint">
                {{i18n "voice.voice_settings.subtitles_hint"}}
              </p>
            </div>
          {{/if}}

          {{#if this.showQuality}}
            <div class="voice-voice-settings__field">
              <label class="voice-voice-settings__label">
                {{i18n "voice.voice_settings.quality"}}
              </label>
              <ComboBox
                @content={{this.qualityOptions}}
                @value={{this.voiceWebrtc.voiceQuality}}
                @onChange={{this.voiceWebrtc.setVoiceQuality}}
                @options={{hash none=false}}
                class="voice-voice-settings__quality-select"
              />
              <p class="voice-voice-settings__hint">
                {{i18n "voice.voice_settings.quality_hint"}}
              </p>
            </div>
          {{/if}}
        </div>
      </:body>
    </DModal>
  </template>
}
