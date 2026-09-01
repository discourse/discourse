import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  isAiMode,
  NOISE_SUPPRESSION_MODES,
} from "../../lib/voice/audio-processing";
import {
  enumerateAudioDevices,
  enumerateVideoDevices,
  outputSelectionSupported,
  SYSTEM_DEFAULT_DEVICE_ID,
} from "../../lib/voice/media-devices";
import { prefetchEngineAssets } from "../../lib/voice/noise-suppression";
import {
  engineForMode,
  noiseSuppressionModeLabel,
} from "../../lib/voice/ns-engines";
import { queuePosition } from "../../lib/voice/speak-queue";
import VoiceVideoSettingsModal from "../modal/voice-video-settings";
import VoiceVoiceSettingsModal from "../modal/voice-voice-settings";
import VoiceCallSubmenu from "./call-submenu";

const AUDIO_MENU = "voice-audio-menu";
const VIDEO_MENU = "voice-video-menu";
const SUBMENU = "voice-call-submenu";

// The audio/video capture controls shared by the room page and the persistent
// call widget: mic and camera "combo" buttons (a toggle plus a caret opening
// device pickers and settings), plus the deafen and screen-share buttons.
//
// Hosts render this inside their own `__controls` footer and append their
// context-specific tail (overflow menu, leave button, etc.) as siblings.
export default class VoiceCallControls extends Component {
  @service currentUser;
  @service dialog;
  @service menu;
  @service modal;
  @service voiceWebrtc;
  @service siteSettings;

  @tracked audioInputDevices = [];
  @tracked audioOutputDevices = [];
  @tracked videoInputDevices = [];
  @tracked recordingPending = false;

  get room() {
    return this.args.room;
  }

  get videoAllowed() {
    return this.voiceWebrtc.videoAllowedIn(this.room);
  }

  get cameraActive() {
    return this.voiceWebrtc.localVideoKind === "camera";
  }

  get screenShareActive() {
    return this.voiceWebrtc.localVideoKind === "screen";
  }

  get cameraDisabled() {
    return (
      !this.cameraActive && !this.voiceWebrtc.canPublishVideo(this.room?.id)
    );
  }

  get screenShareDisabled() {
    return (
      !this.screenShareActive &&
      !this.voiceWebrtc.canPublishVideo(this.room?.id)
    );
  }

  get showScreenShare() {
    return this.videoAllowed && this.voiceWebrtc.screenShareSupported;
  }

  get #ownParticipant() {
    return (this.room?.active_participants || []).find(
      (participant) => Number(participant?.id) === this.currentUser?.id
    );
  }

  get isStageListener() {
    if (this.room?.room_type !== "stage") {
      return false;
    }
    const role = this.#ownParticipant?.role;
    return !!this.#ownParticipant && role !== "moderator" && role !== "speaker";
  }

  get handRaisedAt() {
    return this.#ownParticipant?.hand_raised_at;
  }

  get raiseHandTitle() {
    if (!this.handRaisedAt) {
      return i18n("voice.stage.raise_hand");
    }

    const position = queuePosition(this.room, this.currentUser?.id);
    const lowerHand = i18n("voice.stage.lower_hand");
    return position
      ? `${lowerHand} — ${i18n("voice.stage.queue_position", { position })}`
      : lowerHand;
  }

  get noiseSuppressionOn() {
    return this.voiceWebrtc.noiseSuppressionState === "on";
  }

  get noiseSuppressionStarting() {
    return this.voiceWebrtc.noiseSuppressionState === "starting";
  }

  // Standard (native) suppression is the browser default everywhere, so
  // only the AI mode earns an indicator.
  get showNoiseSuppressionBadge() {
    return (
      this.voiceWebrtc.audioEnabled &&
      isAiMode(this.voiceWebrtc.noiseSuppressionMode) &&
      this.voiceWebrtc.noiseSuppressionState !== "off"
    );
  }

  get currentNoiseSuppressionModeName() {
    return noiseSuppressionModeLabel(this.voiceWebrtc.noiseSuppressionMode);
  }

  get micTitle() {
    if (this.voiceWebrtc.pttEnabled) {
      return i18n("voice.ptt.controlled_by_ptt");
    }
    const title = this.voiceWebrtc.audioEnabled
      ? i18n("voice.room.mic_on")
      : i18n("voice.room.mic_off");
    if (this.showNoiseSuppressionBadge && this.noiseSuppressionOn) {
      return `${title} — ${i18n("voice.room.noise_suppression_active")}`;
    }
    return title;
  }

  get cameraTitle() {
    return this.cameraActive
      ? i18n("voice.video.camera_off")
      : i18n("voice.video.camera_on");
  }

  get screenShareTitle() {
    return this.screenShareActive
      ? i18n("voice.video.screen_share_stop")
      : i18n("voice.video.screen_share_start");
  }

  get deafenTitle() {
    return this.voiceWebrtc.deafened
      ? i18n("voice.room.deafen_off")
      : i18n("voice.room.deafen_on");
  }

  get audioOutputSupported() {
    return outputSelectionSupported();
  }

  get canRecord() {
    return (
      this.room?.can_manage &&
      this.siteSettings.voice_livekit_recording_enabled &&
      this.voiceWebrtc.isLivekitRoom(this.room?.id)
    );
  }

  get recordingActive() {
    return !!this.room?.recording;
  }

  get recordTitle() {
    return this.recordingActive
      ? i18n("voice.room.recording_stop")
      : i18n("voice.room.recording_start");
  }

  get currentInputDeviceName() {
    return this.audioInputDevices.find(
      (device) => device.id === this.voiceWebrtc.inputDeviceId
    )?.name;
  }

  get currentOutputDeviceName() {
    return this.audioOutputDevices.find(
      (device) => device.id === this.voiceWebrtc.outputDeviceId
    )?.name;
  }

  get currentVideoDeviceName() {
    return this.videoInputDevices.find(
      (device) => device.id === this.voiceWebrtc.videoInputDeviceId
    )?.name;
  }

  @action
  toggleMute() {
    this.voiceWebrtc.toggleMute();
  }

  @action
  toggleDeafen() {
    this.voiceWebrtc.toggleDeafen();
  }

  @action
  toggleCamera() {
    this.voiceWebrtc.toggleCamera();
  }

  @action
  toggleScreenShare() {
    this.voiceWebrtc.toggleScreenShare();
  }

  @action
  async toggleRaiseHand() {
    try {
      await ajax(`/voice/rooms/${this.room.id}/request_to_speak`, {
        type: this.handRaisedAt ? "DELETE" : "POST",
        data: {
          participant_session_id: this.voiceWebrtc.participantSessionIdFor(
            this.room.id
          ),
        },
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  toggleRecording() {
    const stopping = this.recordingActive;

    this.dialog.yesNoConfirm({
      message: stopping
        ? i18n("voice.room.recording_stop_confirm")
        : i18n("voice.room.recording_confirm"),
      didConfirm: async () => {
        this.recordingPending = true;
        try {
          // The room-wide "recording" broadcast flips the button and shows
          // the indicator; no local state to update here.
          await ajax(`/voice/rooms/${this.room.id}/recording`, {
            type: stopping ? "DELETE" : "POST",
          });
        } catch (error) {
          popupAjaxError(error);
        } finally {
          this.recordingPending = false;
        }
      },
    });
  }

  @action
  openVoiceSettings(closeMenu) {
    closeMenu?.();
    this.modal.show(VoiceVoiceSettingsModal);
  }

  @action
  openVideoSettings(closeMenu) {
    closeMenu?.();
    this.modal.show(VoiceVideoSettingsModal);
  }

  @action
  openNoiseSuppressionMenu(_actionArg, event) {
    this.#openSubmenu(
      event,
      AUDIO_MENU,
      NOISE_SUPPRESSION_MODES.map((mode) => ({
        id: mode,
        label: noiseSuppressionModeLabel(mode),
        selected: mode === this.voiceWebrtc.noiseSuppressionMode,
      })),
      (mode) => this.voiceWebrtc.setNoiseSuppressionMode(mode)
    );
  }

  @action
  async loadAudioDevices() {
    // If the persisted mode is an AI engine, warming its assets makes the
    // next enable (rejoin, unmute) near-instant.
    const engine = engineForMode(this.voiceWebrtc.noiseSuppressionMode);
    if (engine) {
      prefetchEngineAssets(engine).catch(() => {});
    }
    const { inputs, outputs } = await enumerateAudioDevices();
    if (this.isDestroying || this.isDestroyed) {
      return;
    }
    const defaultDevice = this.#systemDefaultDevice();
    this.audioInputDevices = [defaultDevice, ...inputs];
    this.audioOutputDevices = [defaultDevice, ...outputs];
  }

  @action
  async loadVideoDevices() {
    const inputs = await enumerateVideoDevices();
    if (this.isDestroying || this.isDestroyed) {
      return;
    }
    this.videoInputDevices = [this.#systemDefaultDevice(), ...inputs];
  }

  @action
  openInputDeviceMenu(_actionArg, event) {
    this.#openSubmenu(
      event,
      AUDIO_MENU,
      this.#deviceItems(this.audioInputDevices, this.voiceWebrtc.inputDeviceId),
      (id) => this.voiceWebrtc.setInputDevice(id)
    );
  }

  @action
  openOutputDeviceMenu(_actionArg, event) {
    this.#openSubmenu(
      event,
      AUDIO_MENU,
      this.#deviceItems(
        this.audioOutputDevices,
        this.voiceWebrtc.outputDeviceId
      ),
      (id) => this.voiceWebrtc.setOutputDevice(id)
    );
  }

  @action
  openCameraMenu(_actionArg, event) {
    this.#openSubmenu(
      event,
      VIDEO_MENU,
      this.#deviceItems(
        this.videoInputDevices,
        this.voiceWebrtc.videoInputDeviceId
      ),
      (id) => this.voiceWebrtc.setVideoInputDevice(id)
    );
  }

  #systemDefaultDevice() {
    return {
      id: SYSTEM_DEFAULT_DEVICE_ID,
      name: i18n("voice.devices.system_default"),
    };
  }

  // Opened programmatically (not a nested <DMenu>) so the trigger stays a
  // normal full-width menu item, matching core's channel context menu.
  #openSubmenu(event, parentMenu, items, onSelect) {
    // Anchor to the row button, not the clicked icon/label, so the submenu
    // opens flush to the row's right edge.
    const anchor = event.target.closest(".btn") ?? event.target;
    this.menu.show(anchor, {
      identifier: SUBMENU,
      groupIdentifier: SUBMENU,
      component: VoiceCallSubmenu,
      placement: "right-start",
      offset: { mainAxis: 8, crossAxis: -5 },
      modalForMobile: true,
      data: {
        items,
        onSelect: (id) => {
          onSelect(id);
          this.menu.close(parentMenu);
        },
      },
    });
  }

  #deviceItems(devices, currentId) {
    return devices.map((device) => ({
      id: device.id,
      label: device.name,
      selected: device.id === currentId,
    }));
  }

  <template>
    <div class="voice-call-controls__combo">
      <DButton
        @action={{this.toggleMute}}
        @icon={{if
          this.voiceWebrtc.audioEnabled
          "microphone"
          "microphone-slash"
        }}
        @translatedTitle={{this.micTitle}}
        @disabled={{this.voiceWebrtc.pttEnabled}}
        class={{dConcatClass
          "btn-default voice-call-controls__combo-main"
          (if this.voiceWebrtc.audioEnabled "" "--off")
        }}
      >
        {{#if this.showNoiseSuppressionBadge}}
          <span
            class={{dConcatClass
              "voice-call-controls__ns-badge"
              (if this.noiseSuppressionStarting "--starting")
            }}
            aria-hidden="true"
          >
            {{dIcon "discourse-sparkles"}}
          </span>
        {{/if}}
      </DButton>
      <DMenu
        @identifier="voice-audio-menu"
        @icon="angle-down"
        @title={{i18n "voice.room.audio_options"}}
        @ariaLabel={{i18n "voice.room.audio_options"}}
        @placement="top-end"
        @onShow={{this.loadAudioDevices}}
        @triggerClass="btn-default voice-call-controls__combo-caret"
      >
        <:content as |audioMenu|>
          <DDropdownMenu as |dropdown|>
            <dropdown.item>
              <DButton
                @action={{this.openInputDeviceMenu}}
                @forwardEvent={{true}}
                @icon="microphone"
                @label="voice.voice_settings.input_audio"
                @suffixIcon="angle-right"
                class="btn-transparent voice-call-menu__device-row"
              >
                {{#if this.currentInputDeviceName}}
                  <span class="voice-call-menu__current-device">
                    {{this.currentInputDeviceName}}
                  </span>
                {{/if}}
              </DButton>
            </dropdown.item>
            {{#if this.audioOutputSupported}}
              <dropdown.item>
                <DButton
                  @action={{this.openOutputDeviceMenu}}
                  @forwardEvent={{true}}
                  @icon="volume-high"
                  @label="voice.voice_settings.output_audio"
                  @suffixIcon="angle-right"
                  class="btn-transparent voice-call-menu__device-row"
                >
                  {{#if this.currentOutputDeviceName}}
                    <span class="voice-call-menu__current-device">
                      {{this.currentOutputDeviceName}}
                    </span>
                  {{/if}}
                </DButton>
              </dropdown.item>
            {{/if}}
            <dropdown.divider />
            <dropdown.item>
              <DButton
                @action={{this.openNoiseSuppressionMenu}}
                @forwardEvent={{true}}
                @icon="discourse-sparkles"
                @label="voice.voice_settings.noise_suppression"
                @suffixIcon="angle-right"
                @disabled={{this.noiseSuppressionStarting}}
                class="btn-transparent voice-call-menu__device-row voice-call-menu__noise-suppression"
              >
                <span class="voice-call-menu__current-device">
                  {{this.currentNoiseSuppressionModeName}}
                </span>
              </DButton>
            </dropdown.item>
            <dropdown.item>
              <DButton
                @action={{fn this.openVoiceSettings audioMenu.close}}
                @icon="sliders"
                @label="voice.voice_settings.audio_settings"
                class="btn-transparent"
              />
            </dropdown.item>
          </DDropdownMenu>
        </:content>
      </DMenu>
    </div>
    {{#if this.isStageListener}}
      <DButton
        @action={{this.toggleRaiseHand}}
        @icon="hand"
        @translatedTitle={{this.raiseHandTitle}}
        class={{dConcatClass
          "btn-default voice-call-controls__raise-hand"
          (if this.handRaisedAt "--active")
        }}
      />
    {{/if}}
    {{! Capture buttons are plain <button>s on purpose: DButton defers its
    action via next(), which lands outside the click event dispatch — Firefox
    only allows getDisplayMedia during the actual dispatch, so a deferred call
    throws NotAllowedError. }}
    {{#if this.videoAllowed}}
      <div class="voice-call-controls__combo">
        <button
          type="button"
          class={{dConcatClass
            "btn btn-icon no-text btn-default voice-call-controls__combo-main"
            (if this.cameraActive "--active")
          }}
          title={{this.cameraTitle}}
          aria-label={{this.cameraTitle}}
          disabled={{this.cameraDisabled}}
          {{on "click" this.toggleCamera}}
        >
          {{dIcon (if this.cameraActive "video" "video-slash")}}
          {{! Zero-width space: matches DButton so an icon-only button keeps
          full button height and aligns with its DButton siblings. }}
          <span aria-hidden="true">&#8203;</span>
        </button>
        <DMenu
          @identifier="voice-video-menu"
          @icon="angle-down"
          @title={{i18n "voice.room.video_options"}}
          @ariaLabel={{i18n "voice.room.video_options"}}
          @placement="top-end"
          @onShow={{this.loadVideoDevices}}
          @triggerClass="btn-default voice-call-controls__combo-caret"
        >
          <:content as |videoMenu|>
            <DDropdownMenu as |dropdown|>
              <dropdown.item>
                <DButton
                  @action={{this.openCameraMenu}}
                  @forwardEvent={{true}}
                  @icon="video"
                  @label="voice.video_settings.camera"
                  @suffixIcon="angle-right"
                  class="btn-transparent voice-call-menu__device-row"
                >
                  {{#if this.currentVideoDeviceName}}
                    <span class="voice-call-menu__current-device">
                      {{this.currentVideoDeviceName}}
                    </span>
                  {{/if}}
                </DButton>
              </dropdown.item>
              <dropdown.divider />
              <dropdown.item>
                <DButton
                  @action={{fn this.openVideoSettings videoMenu.close}}
                  @icon="sliders"
                  @label="voice.video_settings.title"
                  class="btn-transparent"
                />
              </dropdown.item>
            </DDropdownMenu>
          </:content>
        </DMenu>
      </div>
    {{/if}}
    <DButton
      @action={{this.toggleDeafen}}
      @icon={{if this.voiceWebrtc.deafened "volume-xmark" "ear-listen"}}
      @translatedTitle={{this.deafenTitle}}
      class={{dConcatClass
        "btn-default"
        (if this.voiceWebrtc.deafened "--off" "")
      }}
    />
    {{#if this.canRecord}}
      <DButton
        @action={{this.toggleRecording}}
        @icon="record-vinyl"
        @translatedTitle={{this.recordTitle}}
        @disabled={{this.recordingPending}}
        class={{dConcatClass
          "btn-default voice-call-controls__record"
          (if this.recordingActive "--recording")
        }}
      />
    {{/if}}
    {{#if this.showScreenShare}}
      <button
        type="button"
        class={{dConcatClass
          "btn btn-icon no-text btn-default"
          (if this.screenShareActive "--active")
        }}
        title={{this.screenShareTitle}}
        aria-label={{this.screenShareTitle}}
        disabled={{this.screenShareDisabled}}
        {{on "click" this.toggleScreenShare}}
      >
        {{dIcon "display"}}
        <span aria-hidden="true">&#8203;</span>
      </button>
    {{/if}}
  </template>
}
