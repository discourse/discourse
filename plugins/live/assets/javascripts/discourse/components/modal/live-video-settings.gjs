import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import ComboBox from "discourse/select-kit/components/combo-box";
import DModal from "discourse/ui-kit/d-modal";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import { i18n } from "discourse-i18n";
import BackgroundBlurManager from "../../lib/live/background-blur.js";
import {
  cameraConstraints,
  enumerateVideoDevices,
  SYSTEM_DEFAULT_DEVICE_ID,
} from "../../lib/live/media-devices.js";

export default class LiveVideoSettingsModal extends Component {
  @service liveWebrtc;

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
    return this.liveWebrtc.videoBlurAvailable;
  }

  get blurSupported() {
    return this.liveWebrtc.videoBlurSupported;
  }

  get blurUsable() {
    return this.blurAvailable && this.blurSupported;
  }

  get blurEnabled() {
    return this.liveWebrtc.videoBlurEnabled;
  }

  get blurAmount() {
    return this.liveWebrtc.videoBlurAmount;
  }

  get usingLiveStream() {
    return this.liveWebrtc.localVideoKind === "camera";
  }

  get cameraQualityOptions() {
    return this.liveWebrtc.allowedCameraQualityTiers().map((tier) => ({
      id: tier,
      name: i18n(`live.quality.${tier}`),
    }));
  }

  get screenQualityOptions() {
    return this.liveWebrtc.allowedScreenQualityTiers().map((tier) => ({
      id: tier,
      name: i18n(`live.quality.${tier}`),
    }));
  }

  get screenContentOptions() {
    return ["text", "motion"].map((content) => ({
      id: content,
      name: i18n(`live.video_settings.screen_content_${content}`),
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
      ? this.liveWebrtc.localVideoStream
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
          this.liveWebrtc.videoInputDeviceId,
          this.liveWebrtc.effectiveCameraQuality()
        ),
      });
    } catch {
      if (!this.isDestroying) {
        this.previewError = true;
      }
      return;
    }

    if (epoch !== this.#previewEpoch || this.isDestroying) {
      stream.getTracks().forEach((track) => track.stop());
      return;
    }

    this.#previewRawStream = stream;
    await this.#applyPreviewEffect(epoch);
    await this.refreshDevices();
  }

  async refreshDevices() {
    const inputs = await enumerateVideoDevices();
    if (this.isDestroying) {
      return;
    }

    this.videoDevices = [
      {
        id: SYSTEM_DEFAULT_DEVICE_ID,
        name: i18n("live.devices.system_default"),
      },
      ...inputs,
    ];
  }

  @action
  async onCameraChange(deviceId) {
    await this.liveWebrtc.setVideoInputDevice(deviceId);
    if (!this.usingLiveStream) {
      await this.startPreview();
    }
  }

  @action
  async onCameraQualityChange(tier) {
    this.liveWebrtc.setCameraQuality(tier);
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
      await this.liveWebrtc.toggleVideoBlur();
      if (!this.usingLiveStream) {
        await this.#applyPreviewEffect();
      }
    } finally {
      if (!this.isDestroying) {
        this.busy = false;
      }
    }
  }

  @action
  onAmountChange(event) {
    const value = parseInt(event.target.value, 10);
    this.liveWebrtc.setVideoBlurAmount(value);
    this.#previewBlur?.setAmount(value);
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
        if (epoch !== this.#previewEpoch || this.isDestroying) {
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

  <template>
    <DModal
      class="live-video-settings-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "live.video_settings.title"}}
    >
      <:body>
        <div class="live-video-settings">
          <div class="live-video-settings__preview">
            {{#if this.previewError}}
              <p class="live-video-settings__camera-error">
                {{i18n "live.video_settings.camera_error"}}
              </p>
            {{else if this.stream}}
              <video
                autoplay
                muted
                playsinline
                {{didInsert (fn this.liveWebrtc.attachVideoStream this.stream)}}
                {{didUpdate
                  (fn this.liveWebrtc.attachVideoStream this.stream)
                  this.stream
                }}
              ></video>
            {{/if}}
          </div>

          <div class="live-video-settings__field">
            <label class="live-video-settings__label">
              {{i18n "live.video_settings.camera"}}
            </label>
            <ComboBox
              class="live-video-settings__camera-select"
              @content={{this.videoDevices}}
              @onChange={{this.onCameraChange}}
              @options={{hash none=false}}
              @value={{this.liveWebrtc.videoInputDeviceId}}
            />
          </div>

          {{#if this.showCameraQuality}}
            <div class="live-video-settings__field">
              <label class="live-video-settings__label">
                {{i18n "live.video_settings.camera_quality"}}
              </label>
              <ComboBox
                class="live-video-settings__camera-quality-select"
                @content={{this.cameraQualityOptions}}
                @onChange={{this.onCameraQualityChange}}
                @options={{hash none=false}}
                @value={{this.liveWebrtc.cameraQuality}}
              />
              <p class="live-video-settings__hint">
                {{i18n "live.video_settings.camera_quality_hint"}}
              </p>
            </div>
          {{/if}}

          {{#if this.showScreenQuality}}
            <div class="live-video-settings__field">
              <label class="live-video-settings__label">
                {{i18n "live.video_settings.screen_quality"}}
              </label>
              <ComboBox
                class="live-video-settings__screen-quality-select"
                @content={{this.screenQualityOptions}}
                @onChange={{this.liveWebrtc.setScreenQuality}}
                @options={{hash none=false}}
                @value={{this.liveWebrtc.screenQuality}}
              />
              <p class="live-video-settings__hint">
                {{i18n "live.video_settings.screen_quality_hint"}}
              </p>
            </div>
          {{/if}}

          <div class="live-video-settings__field">
            <label class="live-video-settings__label">
              {{i18n "live.video_settings.screen_content"}}
            </label>
            <ComboBox
              class="live-video-settings__screen-content-select"
              @content={{this.screenContentOptions}}
              @onChange={{this.liveWebrtc.setScreenContent}}
              @options={{hash none=false}}
              @value={{this.liveWebrtc.screenContent}}
            />
            <p class="live-video-settings__hint">
              {{i18n "live.video_settings.screen_content_hint"}}
            </p>
          </div>

          {{#if this.blurAvailable}}
            <div class="live-video-settings__field">
              <DToggleSwitch
                disabled={{or this.busy (not this.blurSupported)}}
                @label="live.video_settings.background_blur"
                @state={{this.blurEnabled}}
                {{on "click" this.toggleBlur}}
              />
              {{#unless this.blurSupported}}
                <p class="live-video-settings__hint">
                  {{i18n "live.video_settings.not_supported"}}
                </p>
              {{/unless}}
            </div>

            {{#if (and this.blurEnabled this.blurSupported)}}
              <div class="live-video-settings__field">
                <label
                  class="live-video-settings__label"
                  for="live-video-settings-blur-amount"
                >
                  {{i18n "live.video_settings.blur_amount"}}
                </label>
                <input
                  class="live-video-settings__blur-slider"
                  id="live-video-settings-blur-amount"
                  max="100"
                  min="0"
                  type="range"
                  value={{this.blurAmount}}
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
