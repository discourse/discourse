import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import ComboBox from "discourse/select-kit/components/combo-box";
import { and, not, or } from "discourse/truth-helpers";
import DModal from "discourse/ui-kit/d-modal";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import { i18n } from "discourse-i18n";
import BackgroundBlurManager from "../../lib/voice/background-blur";
import {
  cameraConstraints,
  enumerateVideoDevices,
  SYSTEM_DEFAULT_DEVICE_ID,
} from "../../lib/voice/media-devices";

export default class VoiceVideoSettingsModal extends Component {
  @service voiceWebrtc;

  @tracked videoDevices = [];
  @tracked previewStream = null;
  @tracked previewError = false;
  @tracked busy = false;

  #previewRawStream = null;
  #previewBlur = null;
  #previewEpoch = 0;
  #onDeviceChange = () => this.refreshDevices();

  constructor() {
    super(...arguments);
    if (this.usingLiveStream) {
      this.refreshDevices();
    } else {
      this.startPreview();
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

  get blurAvailable() {
    return this.voiceWebrtc.videoBlurAvailable;
  }

  get blurSupported() {
    return this.voiceWebrtc.videoBlurSupported;
  }

  get blurUsable() {
    return this.blurAvailable && this.blurSupported;
  }

  get blurEnabled() {
    return this.voiceWebrtc.videoBlurEnabled;
  }

  get blurAmount() {
    return this.voiceWebrtc.videoBlurAmount;
  }

  get usingLiveStream() {
    return this.voiceWebrtc.localVideoKind === "camera";
  }

  get cameraQualityOptions() {
    return this.voiceWebrtc.allowedCameraQualityTiers().map((tier) => ({
      id: tier,
      name: i18n(`voice.quality.${tier}`),
    }));
  }

  get screenQualityOptions() {
    return this.voiceWebrtc.allowedScreenQualityTiers().map((tier) => ({
      id: tier,
      name: i18n(`voice.quality.${tier}`),
    }));
  }

  get screenContentOptions() {
    return ["text", "motion"].map((content) => ({
      id: content,
      name: i18n(`voice.video_settings.screen_content_${content}`),
    }));
  }

  get showCameraQuality() {
    return this.cameraQualityOptions.length > 1;
  }

  get showScreenQuality() {
    return this.screenQualityOptions.length > 1;
  }

  get stream() {
    return this.usingLiveStream
      ? this.voiceWebrtc.localVideoStream
      : this.previewStream;
  }

  async startPreview() {
    this.#stopPreview();
    const epoch = ++this.#previewEpoch;
    this.previewError = false;

    let stream;
    try {
      stream = await navigator.mediaDevices.getUserMedia({
        video: cameraConstraints(
          this.voiceWebrtc.videoInputDeviceId,
          this.voiceWebrtc.effectiveCameraQuality()
        ),
      });
    } catch {
      if (!this.isDestroying && !this.isDestroyed) {
        this.previewError = true;
      }
      return;
    }

    if (epoch !== this.#previewEpoch || this.isDestroying || this.isDestroyed) {
      stream.getTracks().forEach((track) => track.stop());
      return;
    }

    this.#previewRawStream = stream;
    await this.#applyPreviewEffect(epoch);
    await this.refreshDevices();
  }

  async refreshDevices() {
    const inputs = await enumerateVideoDevices();
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    this.videoDevices = [
      {
        id: SYSTEM_DEFAULT_DEVICE_ID,
        name: i18n("voice.devices.system_default"),
      },
      ...inputs,
    ];
  }

  async #applyPreviewEffect(epoch = this.#previewEpoch) {
    this.#previewBlur?.teardown();
    this.#previewBlur = null;

    if (!this.#previewRawStream) {
      return;
    }

    if (this.blurEnabled && this.blurUsable) {
      const manager = new BackgroundBlurManager();
      const rawStream = this.#previewRawStream;
      try {
        const processed = await manager.setup(rawStream, this.blurAmount);
        if (
          epoch !== this.#previewEpoch ||
          this.isDestroying ||
          this.isDestroyed
        ) {
          manager.teardown();
          return;
        }
        this.#previewBlur = manager;
        this.previewStream = processed;
        return;
      } catch {
        manager.teardown();
      }

      if (epoch !== this.#previewEpoch) {
        return;
      }
    }

    this.previewStream = this.#previewRawStream;
  }

  #stopPreview() {
    this.#previewEpoch++;
    this.#previewBlur?.teardown();
    this.#previewBlur = null;

    if (this.#previewRawStream) {
      this.#previewRawStream.getTracks().forEach((track) => track.stop());
      this.#previewRawStream = null;
    }

    this.previewStream = null;
  }

  @action
  async onCameraChange(deviceId) {
    await this.voiceWebrtc.setVideoInputDevice(deviceId);
    if (!this.usingLiveStream) {
      await this.startPreview();
    }
  }

  @action
  async onCameraQualityChange(tier) {
    this.voiceWebrtc.setCameraQuality(tier);
    if (!this.usingLiveStream) {
      await this.startPreview();
    }
  }

  @action
  async toggleBlur() {
    if (this.busy || !this.blurUsable) {
      return;
    }

    this.busy = true;
    try {
      await this.voiceWebrtc.toggleVideoBlur();
      if (!this.usingLiveStream) {
        await this.#applyPreviewEffect();
      }
    } finally {
      if (!this.isDestroying && !this.isDestroyed) {
        this.busy = false;
      }
    }
  }

  @action
  onAmountChange(event) {
    const value = parseInt(event.target.value, 10);
    this.voiceWebrtc.setVideoBlurAmount(value);
    this.#previewBlur?.setAmount(value);
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "voice.video_settings.title"}}
      class="voice-video-settings-modal"
    >
      <:body>
        <div class="voice-video-settings">
          <div class="voice-video-settings__preview">
            {{#if this.previewError}}
              <p class="voice-video-settings__camera-error">
                {{i18n "voice.video_settings.camera_error"}}
              </p>
            {{else if this.stream}}
              <video
                {{didInsert
                  (fn this.voiceWebrtc.attachVideoStream this.stream)
                }}
                {{didUpdate
                  (fn this.voiceWebrtc.attachVideoStream this.stream)
                  this.stream
                }}
                muted
                autoplay
                playsinline
              ></video>
            {{/if}}
          </div>

          <div class="voice-video-settings__field">
            <label class="voice-video-settings__label">
              {{i18n "voice.video_settings.camera"}}
            </label>
            <ComboBox
              @content={{this.videoDevices}}
              @value={{this.voiceWebrtc.videoInputDeviceId}}
              @onChange={{this.onCameraChange}}
              @options={{hash none=false}}
              class="voice-video-settings__camera-select"
            />
          </div>

          {{#if this.showCameraQuality}}
            <div class="voice-video-settings__field">
              <label class="voice-video-settings__label">
                {{i18n "voice.video_settings.camera_quality"}}
              </label>
              <ComboBox
                @content={{this.cameraQualityOptions}}
                @value={{this.voiceWebrtc.cameraQuality}}
                @onChange={{this.onCameraQualityChange}}
                @options={{hash none=false}}
                class="voice-video-settings__camera-quality-select"
              />
              <p class="voice-video-settings__hint">
                {{i18n "voice.video_settings.camera_quality_hint"}}
              </p>
            </div>
          {{/if}}

          {{#if this.showScreenQuality}}
            <div class="voice-video-settings__field">
              <label class="voice-video-settings__label">
                {{i18n "voice.video_settings.screen_quality"}}
              </label>
              <ComboBox
                @content={{this.screenQualityOptions}}
                @value={{this.voiceWebrtc.screenQuality}}
                @onChange={{this.voiceWebrtc.setScreenQuality}}
                @options={{hash none=false}}
                class="voice-video-settings__screen-quality-select"
              />
              <p class="voice-video-settings__hint">
                {{i18n "voice.video_settings.screen_quality_hint"}}
              </p>
            </div>
          {{/if}}

          <div class="voice-video-settings__field">
            <label class="voice-video-settings__label">
              {{i18n "voice.video_settings.screen_content"}}
            </label>
            <ComboBox
              @content={{this.screenContentOptions}}
              @value={{this.voiceWebrtc.screenContent}}
              @onChange={{this.voiceWebrtc.setScreenContent}}
              @options={{hash none=false}}
              class="voice-video-settings__screen-content-select"
            />
            <p class="voice-video-settings__hint">
              {{i18n "voice.video_settings.screen_content_hint"}}
            </p>
          </div>

          {{#if this.blurAvailable}}
            <div class="voice-video-settings__field">
              <DToggleSwitch
                @state={{this.blurEnabled}}
                @label="voice.video_settings.background_blur"
                disabled={{or this.busy (not this.blurSupported)}}
                {{on "click" this.toggleBlur}}
              />
              {{#unless this.blurSupported}}
                <p class="voice-video-settings__hint">
                  {{i18n "voice.video_settings.not_supported"}}
                </p>
              {{/unless}}
            </div>

            {{#if (and this.blurEnabled this.blurSupported)}}
              <div class="voice-video-settings__field">
                <label
                  class="voice-video-settings__label"
                  for="voice-video-settings-blur-amount"
                >
                  {{i18n "voice.video_settings.blur_amount"}}
                </label>
                <input
                  type="range"
                  id="voice-video-settings-blur-amount"
                  min="0"
                  max="100"
                  value={{this.blurAmount}}
                  class="voice-video-settings__blur-slider"
                  {{on "input" this.onAmountChange}}
                />
              </div>
            {{/if}}
          {{/if}}
        </div>
      </:body>
    </DModal>
  </template>
}
