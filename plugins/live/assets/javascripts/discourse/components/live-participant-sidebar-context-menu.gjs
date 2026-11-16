import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import FlagModal from "discourse/components/modal/flag";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";
import { humanKeyName } from "../lib/live/ptt-utils.js";
import LiveFlag from "../lib/live-flag.js";
import LivePttKeyCapture from "./live-ptt-key-capture.gjs";
import LiveVoiceSettingsModal from "./modal/live-voice-settings.gjs";

export default class LiveParticipantSidebarContextMenu extends Component {
  @service currentUser;
  @service modal;
  @service liveWebrtc;
  @service siteSettings;

  @tracked volume = 100;
  @tracked isMuted = false;
  @tracked showKeyCapture = false;

  constructor() {
    super(...arguments);
    const { room, participant } = this.args.data;
    this.volume = Math.round(
      this.liveWebrtc.getParticipantVolume(room.id, participant.id) * 100
    );
    this.isMuted = this.liveWebrtc.isParticipantMuted(room.id, participant.id);
  }

  get room() {
    return this.args.data.room;
  }

  get participant() {
    return this.args.data.participant;
  }

  get isCurrentUser() {
    return this.args.data.isCurrentUser;
  }

  get canManageRoom() {
    return this.args.data.canManageRoom;
  }

  get canSpotlight() {
    return !!this.args.data.onSpotlight;
  }

  get isSpotlighted() {
    return !!this.args.data.isSpotlighted;
  }

  get spotlightLabel() {
    return this.isSpotlighted
      ? i18n("live.participant.remove_spotlight")
      : i18n("live.participant.spotlight");
  }

  get canKick() {
    return this.canManageRoom && this.participant.id !== this.room.creator_id;
  }

  get canFlag() {
    return !!this.currentUser && this.participant.id > 0;
  }

  get isStageRoom() {
    return this.room.room_type === "stage";
  }

  get isListenerInStage() {
    if (!this.isStageRoom || !this.isCurrentUser) {
      return false;
    }
    const role = this.participant.role;
    return role !== "moderator" && role !== "speaker";
  }

  get participantIsSpeakerOrMod() {
    const role = this.participant.role;
    return role === "moderator" || role === "speaker";
  }

  get canPromoteToSpeaker() {
    return (
      this.canManageRoom &&
      this.isStageRoom &&
      !this.participant.external_agent &&
      !this.isCurrentUser &&
      !this.participantIsSpeakerOrMod
    );
  }

  get canDemoteToListener() {
    return (
      this.canManageRoom &&
      this.isStageRoom &&
      !this.participant.external_agent &&
      !this.isCurrentUser &&
      this.participant.role === "speaker"
    );
  }

  get canDismissRequest() {
    return (
      this.canManageRoom &&
      this.isStageRoom &&
      !this.isCurrentUser &&
      !!this.participant.hand_raised_at
    );
  }

  get handRaised() {
    return !!this.participant.hand_raised_at;
  }

  get raiseHandLabel() {
    return this.handRaised
      ? i18n("live.stage.lower_hand")
      : i18n("live.stage.raise_hand");
  }

  get muteLabel() {
    return this.isMuted
      ? i18n("live.participant.unmute")
      : i18n("live.participant.mute");
  }

  get muteIcon() {
    return this.isMuted ? "volume-xmark" : "volume-high";
  }

  get micIcon() {
    return this.liveWebrtc.audioEnabled ? "microphone" : "microphone-slash";
  }

  get micLabel() {
    return this.liveWebrtc.audioEnabled
      ? i18n("live.room.mic_on")
      : i18n("live.room.mic_off");
  }

  get deafenIcon() {
    return this.liveWebrtc.deafened ? "volume-xmark" : "volume-high";
  }

  get deafenLabel() {
    return this.liveWebrtc.deafened
      ? i18n("live.room.deafen_off")
      : i18n("live.room.deafen_on");
  }

  get isPttEnabled() {
    return this.liveWebrtc.pttEnabled;
  }

  get pttToggleLabel() {
    return this.isPttEnabled
      ? i18n("live.ptt.disable")
      : i18n("live.ptt.enable");
  }

  get pttKeyLabel() {
    return i18n("live.ptt.configure_key", {
      key: humanKeyName(this.liveWebrtc.pttKey),
    });
  }

  get micDisabledByPtt() {
    return this.isCurrentUser && this.isPttEnabled;
  }

  get showAutoStatusToggle() {
    return this.isCurrentUser && this.siteSettings.live_auto_status_enabled;
  }

  get autoStatusLabel() {
    return this.liveWebrtc.autoStatusEnabled
      ? i18n("live.status.auto_update_on")
      : i18n("live.status.auto_update_off");
  }

  @action
  onVolumeChange(event) {
    this.volume = parseInt(event.target.value, 10);
    this.liveWebrtc.setParticipantVolume(
      this.room.id,
      this.participant.id,
      this.volume / 100
    );
  }

  @action
  toggleMute() {
    this.isMuted = this.liveWebrtc.toggleParticipantMute(
      this.room.id,
      this.participant.id
    );
  }

  @action
  toggleSpotlight() {
    this.args.data.onSpotlight(this.participant.id);
    this.args.close();
  }

  @action
  async kick() {
    try {
      await ajax(`/live/rooms/${this.room.id}/kick`, {
        type: "DELETE",
        data: { user_id: this.participant.id },
      });
      this.args.close();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  flag() {
    this.args.close();
    this.modal.show(FlagModal, {
      model: {
        flagTarget: new LiveFlag(this.room),
        flagModel: {
          id: this.participant.id,
          user_id: this.participant.id,
          username: this.participant.username,
        },
        setHidden: () => {},
      },
    });
  }

  @action
  toggleMic() {
    this.liveWebrtc.toggleMute();
  }

  @action
  toggleDeafen() {
    this.liveWebrtc.toggleDeafen();
  }

  @action
  toggleAutoStatus() {
    this.liveWebrtc.toggleAutoStatus();
  }

  @action
  openVoiceSettings() {
    this.args.close();
    this.modal.show(LiveVoiceSettingsModal);
  }

  @action
  togglePtt() {
    if (this.isPttEnabled) {
      this.liveWebrtc.disablePtt();
    } else {
      this.liveWebrtc.enablePtt();
    }
  }

  @action
  openKeyCapture() {
    this.showKeyCapture = true;
  }

  @action
  onKeyCaptureConfirm(keyCode) {
    this.liveWebrtc.setPttKey(keyCode);
    this.showKeyCapture = false;
  }

  @action
  onKeyCaptureCancel() {
    this.showKeyCapture = false;
  }

  @action
  async toggleRaiseHand() {
    try {
      await ajax(`/live/rooms/${this.room.id}/request_to_speak`, {
        type: this.handRaised ? "DELETE" : "POST",
        data: {
          participant_session_id: this.liveWebrtc.participantSessionIdFor(
            this.room.id
          ),
        },
      });
      this.args.close();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async dismissRequest() {
    try {
      await ajax(`/live/rooms/${this.room.id}/request_to_speak`, {
        type: "DELETE",
        data: { user_id: this.participant.id },
      });
      this.args.close();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async promoteToSpeaker() {
    await this.#changeParticipantRole("speaker");
  }

  @action
  async demoteToListener() {
    await this.#changeParticipantRole("participant");
  }

  async #changeParticipantRole(newRole) {
    try {
      await ajax(`/live/rooms/${this.room.id}/memberships`, {
        type: "POST",
        data: { user_id: this.participant.id, role: newRole },
      });
      this.args.close();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <DDropdownMenu class="live-participant-sidebar-context-menu" as |dropdown|>
      {{#if this.canSpotlight}}
        <dropdown.item>
          <DButton
            class="live-participant-sidebar-context-menu__spotlight-btn"
            @action={{this.toggleSpotlight}}
            @ariaPressed={{this.isSpotlighted}}
            @icon="person-chalkboard"
            @translatedLabel={{this.spotlightLabel}}
            @translatedTitle={{this.spotlightLabel}}
          />
        </dropdown.item>
      {{/if}}
      {{#if this.isCurrentUser}}
        {{#unless this.isListenerInStage}}
          <dropdown.item>
            <DButton
              class="live-participant-sidebar-context-menu__mic-btn
                {{if this.micDisabledByPtt '--disabled-by-ptt'}}"
              @action={{this.toggleMic}}
              @disabled={{this.micDisabledByPtt}}
              @icon={{this.micIcon}}
              @translatedLabel={{this.micLabel}}
              @translatedTitle={{if
                this.micDisabledByPtt
                (i18n "live.ptt.controlled_by_ptt")
                this.micLabel
              }}
            />
            {{#if this.micDisabledByPtt}}
              <span
                class="live-participant-sidebar-context-menu__ptt-hint"
              >{{i18n "live.ptt.controlled_by_ptt"}}</span>
            {{/if}}
          </dropdown.item>
        {{/unless}}
        <dropdown.item>
          <DButton
            class="live-participant-sidebar-context-menu__deafen-btn"
            @action={{this.toggleDeafen}}
            @icon={{this.deafenIcon}}
            @translatedLabel={{this.deafenLabel}}
            @translatedTitle={{this.deafenLabel}}
          />
        </dropdown.item>
        {{#unless this.isListenerInStage}}
          <dropdown.item>
            <DButton
              class="live-participant-sidebar-context-menu__ptt-btn
                {{if this.isPttEnabled '--active'}}"
              @action={{this.togglePtt}}
              @icon={{if this.isPttEnabled "walkie-talkie" "walkie-talkie"}}
              @translatedLabel={{this.pttToggleLabel}}
              @translatedTitle={{this.pttToggleLabel}}
            />
          </dropdown.item>
          {{#if this.isPttEnabled}}
            <dropdown.item>
              {{#if this.showKeyCapture}}
                <LivePttKeyCapture
                  @onCancel={{this.onKeyCaptureCancel}}
                  @onConfirm={{this.onKeyCaptureConfirm}}
                />
              {{else}}
                <DButton
                  class="live-participant-sidebar-context-menu__ptt-key-btn"
                  @action={{this.openKeyCapture}}
                  @icon="keyboard"
                  @translatedLabel={{this.pttKeyLabel}}
                  @translatedTitle={{this.pttKeyLabel}}
                />
              {{/if}}
            </dropdown.item>
          {{/if}}
        {{/unless}}
        <dropdown.item>
          <DButton
            class="live-participant-sidebar-context-menu__voice-settings-btn"
            @action={{this.openVoiceSettings}}
            @icon="gear"
            @label="live.voice_settings.open"
            @title="live.voice_settings.open"
          />
        </dropdown.item>
        {{#if this.showAutoStatusToggle}}
          <dropdown.item>
            <DButton
              class="live-participant-sidebar-context-menu__auto-status-btn"
              @action={{this.toggleAutoStatus}}
              @icon={{if
                this.liveWebrtc.autoStatusEnabled
                "square-check"
                "far-square"
              }}
              @translatedLabel={{this.autoStatusLabel}}
              @translatedTitle={{this.autoStatusLabel}}
            />
          </dropdown.item>
        {{/if}}
        {{#if this.isListenerInStage}}
          <dropdown.item>
            <DButton
              class="live-participant-sidebar-context-menu__raise-hand-btn
                {{if this.handRaised '--active'}}"
              @action={{this.toggleRaiseHand}}
              @icon="hand"
              @translatedLabel={{this.raiseHandLabel}}
              @translatedTitle={{this.raiseHandLabel}}
            />
          </dropdown.item>
          <dropdown.item>
            <span
              class="live-participant-sidebar-context-menu__stage-hint"
            >{{i18n "live.room.listeners_cannot_unmute"}}</span>
          </dropdown.item>
        {{/if}}
      {{else}}
        {{#if this.participantIsSpeakerOrMod}}
          <dropdown.item class="live-participant-sidebar-context-menu__volume">
            <label class="live-participant-sidebar-context-menu__volume-label">
              {{i18n "live.participant.volume"}}
            </label>
            <input
              class="live-participant-sidebar-context-menu__volume-slider"
              max="100"
              min="0"
              type="range"
              value={{this.volume}}
              {{on "input" this.onVolumeChange}}
            />
          </dropdown.item>
          <dropdown.item>
            <DButton
              class="live-participant-sidebar-context-menu__mute-btn"
              @action={{this.toggleMute}}
              @icon={{this.muteIcon}}
              @translatedLabel={{this.muteLabel}}
              @translatedTitle={{this.muteLabel}}
            />
          </dropdown.item>
        {{else if (not this.isStageRoom)}}
          <dropdown.item class="live-participant-sidebar-context-menu__volume">
            <label class="live-participant-sidebar-context-menu__volume-label">
              {{i18n "live.participant.volume"}}
            </label>
            <input
              class="live-participant-sidebar-context-menu__volume-slider"
              max="100"
              min="0"
              type="range"
              value={{this.volume}}
              {{on "input" this.onVolumeChange}}
            />
          </dropdown.item>
          <dropdown.item>
            <DButton
              class="live-participant-sidebar-context-menu__mute-btn"
              @action={{this.toggleMute}}
              @icon={{this.muteIcon}}
              @translatedLabel={{this.muteLabel}}
              @translatedTitle={{this.muteLabel}}
            />
          </dropdown.item>
        {{/if}}
        {{#if this.canPromoteToSpeaker}}
          <dropdown.item>
            <DButton
              class="live-participant-sidebar-context-menu__promote-btn"
              @action={{this.promoteToSpeaker}}
              @icon="microphone"
              @label="live.stage.make_speaker"
              @title="live.stage.make_speaker"
            />
          </dropdown.item>
        {{/if}}
        {{#if this.canDemoteToListener}}
          <dropdown.item>
            <DButton
              class="live-participant-sidebar-context-menu__demote-btn"
              @action={{this.demoteToListener}}
              @icon="volume-xmark"
              @label="live.stage.move_to_listeners"
              @title="live.stage.move_to_listeners"
            />
          </dropdown.item>
        {{/if}}
        {{#if this.canDismissRequest}}
          <dropdown.item>
            <DButton
              class="live-participant-sidebar-context-menu__dismiss-request-btn"
              @action={{this.dismissRequest}}
              @icon="xmark"
              @label="live.stage.dismiss_request_menu"
              @title="live.stage.dismiss_request_menu"
            />
          </dropdown.item>
        {{/if}}
        {{#if this.canFlag}}
          <dropdown.item>
            <DButton
              class="live-participant-sidebar-context-menu__flag-btn"
              @action={{this.flag}}
              @icon="flag"
              @label="live.participant.flag"
              @title="live.participant.flag"
            />
          </dropdown.item>
        {{/if}}
        {{#if this.canKick}}
          <dropdown.item>
            <DButton
              class="live-participant-sidebar-context-menu__kick-btn btn-danger"
              @action={{this.kick}}
              @icon="right-from-bracket"
              @label="live.participant.kick"
              @title="live.participant.kick"
            />
          </dropdown.item>
        {{/if}}
      {{/if}}
    </DDropdownMenu>
  </template>
}
