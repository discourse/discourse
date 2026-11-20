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
} from "../../lib/live/audio-processing.js";
import {
  enumerateAudioDevices,
  enumerateVideoDevices,
  outputSelectionSupported,
  SYSTEM_DEFAULT_DEVICE_ID,
} from "../../lib/live/media-devices.js";
import { prefetchEngineAssets } from "../../lib/live/noise-suppression.js";
import {
  engineForMode,
  noiseSuppressionModeLabel,
} from "../../lib/live/ns-engines.js";
import { queuePosition } from "../../lib/live/speak-queue.js";
import LiveVideoSettingsModal from "../modal/live-video-settings.gjs";
import LiveVoiceSettingsModal from "../modal/live-voice-settings.gjs";
import LiveCallSubmenu from "./call-submenu.gjs";

const AUDIO_MENU = "live-audio-menu";
const VIDEO_MENU = "live-video-menu";
const SUBMENU = "live-call-submenu";

// The audio/video capture controls shared by the room page and the persistent
// call widget: mic and camera "combo" buttons (a toggle plus a caret opening
// device pickers and settings), plus the deafen and screen-share buttons.
//
// Hosts render this inside their own `__controls` footer and append their
// context-specific tail (overflow menu, leave button, etc.) as siblings.
export default class LiveCallControls extends Component {
  @service currentUser;
  @service dialog;
  @service menu;
  @service modal;
  @service liveWebrtc;
  @service siteSettings;

  @tracked audioInputDevices = [];
  @tracked audioOutputDevices = [];
  @tracked videoInputDevices = [];
  @tracked recordingPending = false;

  get room() {
    return this.args.room;
  }

  get videoAllowed() {
    return this.liveWebrtc.videoAllowedIn(this.room);
  }

  get screenShareAllowed() {
    return this.liveWebrtc.screenShareAllowedIn(this.room);
  }

  get cameraActive() {
    return this.liveWebrtc.localVideoKind === "camera";
  }

  get screenShareActive() {
    return this.liveWebrtc.localVideoKind === "screen";
  }

  get cameraDisabled() {
    return (
      !this.cameraActive && !this.liveWebrtc.canPublishCamera(this.room?.id)
    );
  }

  get screenShareDisabled() {
    return (
      !this.screenShareActive &&
      !this.liveWebrtc.canPublishScreen(this.room?.id)
    );
  }

  get showScreenShare() {
    return this.screenShareAllowed && this.liveWebrtc.screenShareSupported;
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
      return i18n("live.stage.raise_hand");
    }

    const position = queuePosition(this.room, this.currentUser?.id);
    const lowerHand = i18n("live.stage.lower_hand");
    return position
      ? `${lowerHand} — ${i18n("live.stage.queue_position", { position })}`
      : lowerHand;
  }

  get noiseSuppressionOn() {
    return this.liveWebrtc.noiseSuppressionState === "on";
  }

  get noiseSuppressionStarting() {
    return this.liveWebrtc.noiseSuppressionState === "starting";
  }

  // Standard (native) suppression is the browser default everywhere, so
  // only the AI mode earns an indicator.
  get showNoiseSuppressionBadge() {
    return (
      this.liveWebrtc.audioEnabled &&
      isAiMode(this.liveWebrtc.noiseSuppressionMode) &&
      this.liveWebrtc.noiseSuppressionState !== "off"
    );
  }

  get currentNoiseSuppressionModeName() {
    return noiseSuppressionModeLabel(this.liveWebrtc.noiseSuppressionMode);
  }

  get micTitle() {
    if (this.liveWebrtc.pttEnabled) {
      return i18n("live.ptt.controlled_by_ptt");
    }
    const title = this.liveWebrtc.audioEnabled
      ? i18n("live.room.mic_on")
      : i18n("live.room.mic_off");
    if (this.showNoiseSuppressionBadge && this.noiseSuppressionOn) {
      return `${title} — ${i18n("live.room.noise_suppression_active")}`;
    }
    return title;
  }

  get cameraTitle() {
    return this.cameraActive
      ? i18n("live.video.camera_off")
      : i18n("live.video.camera_on");
  }

  get screenShareTitle() {
    return this.screenShareActive
      ? i18n("live.video.screen_share_stop")
      : i18n("live.video.screen_share_start");
  }

  get deafenTitle() {
    return this.liveWebrtc.deafened
      ? i18n("live.room.deafen_off")
      : i18n("live.room.deafen_on");
  }

  get audioOutputSupported() {
    return outputSelectionSupported();
  }

  get canRecord() {
    return (
      this.room?.can_manage &&
      this.siteSettings.live_livekit_recording_enabled &&
      this.liveWebrtc.isLivekitRoom(this.room?.id)
    );
  }

  get recordingActive() {
    return !!this.room?.recording;
  }

  get recordTitle() {
    return this.recordingActive
      ? i18n("live.room.recording_stop")
      : i18n("live.room.recording_start");
  }

  get currentInputDeviceName() {
    return this.audioInputDevices.find(
      (device) => device.id === this.liveWebrtc.inputDeviceId
    )?.name;
  }

  get currentOutputDeviceName() {
    return this.audioOutputDevices.find(
      (device) => device.id === this.liveWebrtc.outputDeviceId
    )?.name;
  }

  get currentVideoDeviceName() {
    return this.videoInputDevices.find(
      (device) => device.id === this.liveWebrtc.videoInputDeviceId
    )?.name;
  }

  @action
  toggleMute() {
    this.liveWebrtc.toggleMute();
  }

  @action
  toggleDeafen() {
    this.liveWebrtc.toggleDeafen();
  }

  @action
  toggleCamera() {
    this.liveWebrtc.toggleCamera();
  }

  @action
  toggleScreenShare() {
    this.liveWebrtc.toggleScreenShare();
  }

  @action
  async toggleRaiseHand() {
    try {
      await ajax(`/live/rooms/${this.room.id}/request_to_speak`, {
        type: this.handRaisedAt ? "DELETE" : "POST",
        data: {
          participant_session_id: this.liveWebrtc.participantSessionIdFor(
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
        ? i18n("live.room.recording_stop_confirm")
        : i18n("live.room.recording_confirm"),
      didConfirm: async () => {
        this.recordingPending = true;
        try {
          // The room-wide "recording" broadcast flips the button and shows
          // the indicator; no local state to update here.
          await ajax(`/live/rooms/${this.room.id}/recording`, {
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
    this.modal.show(LiveVoiceSettingsModal);
  }

  @action
  openVideoSettings(closeMenu) {
    closeMenu?.();
    this.modal.show(LiveVideoSettingsModal);
  }

  @action
  openNoiseSuppressionMenu(_actionArg, event) {
    this.#openSubmenu(
      event,
      AUDIO_MENU,
      NOISE_SUPPRESSION_MODES.map((mode) => ({
        id: mode,
        label: noiseSuppressionModeLabel(mode),
        selected: mode === this.liveWebrtc.noiseSuppressionMode,
      })),
      (mode) => this.liveWebrtc.setNoiseSuppressionMode(mode)
    );
  }

  @action
  async loadAudioDevices() {
    // If the persisted mode is an AI engine, warming its assets makes the
    // next enable (rejoin, unmute) near-instant.
    const engine = engineForMode(this.liveWebrtc.noiseSuppressionMode);
    if (engine) {
      prefetchEngineAssets(engine).catch(() => {});
    }
    const { inputs, outputs } = await enumerateAudioDevices();
    if (this.isDestroying) {
      return;
    }
    const defaultDevice = this.#systemDefaultDevice();
    this.audioInputDevices = [defaultDevice, ...inputs];
    this.audioOutputDevices = [defaultDevice, ...outputs];
  }

  @action
  async loadVideoDevices() {
    const inputs = await enumerateVideoDevices();
    if (this.isDestroying) {
      return;
    }
    this.videoInputDevices = [this.#systemDefaultDevice(), ...inputs];
  }

  @action
  openInputDeviceMenu(_actionArg, event) {
    this.#openSubmenu(
      event,
      AUDIO_MENU,
      this.#deviceItems(this.audioInputDevices, this.liveWebrtc.inputDeviceId),
      (id) => this.liveWebrtc.setInputDevice(id)
    );
  }

  @action
  openOutputDeviceMenu(_actionArg, event) {
    this.#openSubmenu(
      event,
      AUDIO_MENU,
      this.#deviceItems(
        this.audioOutputDevices,
        this.liveWebrtc.outputDeviceId
      ),
      (id) => this.liveWebrtc.setOutputDevice(id)
    );
  }

  @action
  openCameraMenu(_actionArg, event) {
    this.#openSubmenu(
      event,
      VIDEO_MENU,
      this.#deviceItems(
        this.videoInputDevices,
        this.liveWebrtc.videoInputDeviceId
      ),
      (id) => this.liveWebrtc.setVideoInputDevice(id)
    );
  }

  #systemDefaultDevice() {
    return {
      id: SYSTEM_DEFAULT_DEVICE_ID,
      name: i18n("live.devices.system_default"),
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
      component: LiveCallSubmenu,
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
    <div class="live-call-controls__combo">
      <DButton
        class={{dConcatClass
          "btn-default live-call-controls__combo-main"
          (if this.liveWebrtc.audioEnabled "" "--off")
        }}
        @action={{this.toggleMute}}
        @disabled={{this.liveWebrtc.pttEnabled}}
        @icon={{if
          this.liveWebrtc.audioEnabled
          "microphone"
          "microphone-slash"
        }}
        @translatedTitle={{this.micTitle}}
      >
        {{#if this.showNoiseSuppressionBadge}}
          <span
            aria-hidden="true"
            class={{dConcatClass
              "live-call-controls__ns-badge"
              (if this.noiseSuppressionStarting "--starting")
            }}
          >
            {{dIcon "discourse-sparkles"}}
          </span>
        {{/if}}
      </DButton>
      <DMenu
        @ariaLabel={{i18n "live.room.audio_options"}}
        @icon="angle-down"
        @identifier="live-audio-menu"
        @onShow={{this.loadAudioDevices}}
        @placement="top-end"
        @title={{i18n "live.room.audio_options"}}
        @triggerClass="btn-default live-call-controls__combo-caret"
      >
        <:content as |audioMenu|>
          <DDropdownMenu as |dropdown|>
            <dropdown.item>
              <DButton
                class="btn-transparent live-call-menu__device-row"
                @action={{this.openInputDeviceMenu}}
                @forwardEvent={{true}}
                @icon="microphone"
                @label="live.voice_settings.input_audio"
                @suffixIcon="angle-right"
              >
                {{#if this.currentInputDeviceName}}
                  <span class="live-call-menu__current-device">
                    {{this.currentInputDeviceName}}
                  </span>
                {{/if}}
              </DButton>
            </dropdown.item>
            {{#if this.audioOutputSupported}}
              <dropdown.item>
                <DButton
                  class="btn-transparent live-call-menu__device-row"
                  @action={{this.openOutputDeviceMenu}}
                  @forwardEvent={{true}}
                  @icon="volume-high"
                  @label="live.voice_settings.output_audio"
                  @suffixIcon="angle-right"
                >
                  {{#if this.currentOutputDeviceName}}
                    <span class="live-call-menu__current-device">
                      {{this.currentOutputDeviceName}}
                    </span>
                  {{/if}}
                </DButton>
              </dropdown.item>
            {{/if}}
            <dropdown.divider />
            <dropdown.item>
              <DButton
                class="btn-transparent live-call-menu__device-row live-call-menu__noise-suppression"
                @action={{this.openNoiseSuppressionMenu}}
                @disabled={{this.noiseSuppressionStarting}}
                @forwardEvent={{true}}
                @icon="discourse-sparkles"
                @label="live.voice_settings.noise_suppression"
                @suffixIcon="angle-right"
              >
                <span class="live-call-menu__current-device">
                  {{this.currentNoiseSuppressionModeName}}
                </span>
              </DButton>
            </dropdown.item>
            <dropdown.item>
              <DButton
                class="btn-transparent"
                @action={{fn this.openVoiceSettings audioMenu.close}}
                @icon="sliders"
                @label="live.voice_settings.audio_settings"
              />
            </dropdown.item>
          </DDropdownMenu>
        </:content>
      </DMenu>
    </div>
    {{#if this.isStageListener}}
      <DButton
        class={{dConcatClass
          "btn-default live-call-controls__raise-hand"
          (if this.handRaisedAt "--active")
        }}
        @action={{this.toggleRaiseHand}}
        @icon="hand"
        @translatedTitle={{this.raiseHandTitle}}
      />
    {{/if}}
    {{! Capture buttons are plain <button>s on purpose: DButton defers its
    action via next(), which lands outside the click event dispatch — Firefox
    only allows getDisplayMedia during the actual dispatch, so a deferred call
    throws NotAllowedError. }}
    {{#if this.videoAllowed}}
      <div class="live-call-controls__combo">
        <button
          aria-label={{this.cameraTitle}}
          class={{dConcatClass
            "btn btn-icon no-text btn-default live-call-controls__combo-main"
            (if this.cameraActive "--active")
          }}
          disabled={{this.cameraDisabled}}
          title={{this.cameraTitle}}
          type="button"
          {{on "click" this.toggleCamera}}
        >
          {{dIcon (if this.cameraActive "video" "video-slash")}}
          {{! Zero-width space: matches DButton so an icon-only button keeps
          full button height and aligns with its DButton siblings. }}
          <span aria-hidden="true">&#8203;</span>
        </button>
        <DMenu
          @ariaLabel={{i18n "live.room.video_options"}}
          @icon="angle-down"
          @identifier="live-video-menu"
          @onShow={{this.loadVideoDevices}}
          @placement="top-end"
          @title={{i18n "live.room.video_options"}}
          @triggerClass="btn-default live-call-controls__combo-caret"
        >
          <:content as |videoMenu|>
            <DDropdownMenu as |dropdown|>
              <dropdown.item>
                <DButton
                  class="btn-transparent live-call-menu__device-row"
                  @action={{this.openCameraMenu}}
                  @forwardEvent={{true}}
                  @icon="video"
                  @label="live.video_settings.camera"
                  @suffixIcon="angle-right"
                >
                  {{#if this.currentVideoDeviceName}}
                    <span class="live-call-menu__current-device">
                      {{this.currentVideoDeviceName}}
                    </span>
                  {{/if}}
                </DButton>
              </dropdown.item>
              <dropdown.divider />
              <dropdown.item>
                <DButton
                  class="btn-transparent"
                  @action={{fn this.openVideoSettings videoMenu.close}}
                  @icon="sliders"
                  @label="live.video_settings.title"
                />
              </dropdown.item>
            </DDropdownMenu>
          </:content>
        </DMenu>
      </div>
    {{/if}}
    <DButton
      class={{dConcatClass
        "btn-default"
        (if this.liveWebrtc.deafened "--off" "")
      }}
      @action={{this.toggleDeafen}}
      @icon={{if this.liveWebrtc.deafened "volume-xmark" "ear-listen"}}
      @translatedTitle={{this.deafenTitle}}
    />
    {{#if this.canRecord}}
      <DButton
        class={{dConcatClass
          "btn-default live-call-controls__record"
          (if this.recordingActive "--recording")
        }}
        @action={{this.toggleRecording}}
        @disabled={{this.recordingPending}}
        @icon="record-vinyl"
        @translatedTitle={{this.recordTitle}}
      />
    {{/if}}
    {{#if this.showScreenShare}}
      <button
        aria-label={{this.screenShareTitle}}
        class={{dConcatClass
          "btn btn-icon no-text btn-default"
          (if this.screenShareActive "--active")
        }}
        disabled={{this.screenShareDisabled}}
        title={{this.screenShareTitle}}
        type="button"
        {{on "click" this.toggleScreenShare}}
      >
        {{dIcon "display"}}
        <span aria-hidden="true">&#8203;</span>
      </button>
    {{/if}}
  </template>
}
