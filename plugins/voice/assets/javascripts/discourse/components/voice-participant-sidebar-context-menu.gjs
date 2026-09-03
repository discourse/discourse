import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import FlagModal from "discourse/components/modal/flag";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";
import { humanKeyName } from "../lib/voice/ptt-utils";
import VoiceFlag from "../lib/voice-flag";
import VoiceVoiceSettingsModal from "./modal/voice-voice-settings";
import VoicePttKeyCapture from "./voice-ptt-key-capture";

export default class VoiceParticipantSidebarContextMenu extends Component {
  @service currentUser;
  @service modal;
  @service voiceWebrtc;
  @service siteSettings;

  @tracked volume = 100;
  @tracked isMuted = false;
  @tracked showKeyCapture = false;

  constructor() {
    super(...arguments);
    const { room, participant } = this.args.data;
    this.volume = Math.round(
      this.voiceWebrtc.getParticipantVolume(room.id, participant.id) * 100
    );
    this.isMuted = this.voiceWebrtc.isParticipantMuted(room.id, participant.id);
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
      ? i18n("voice.participant.remove_spotlight")
      : i18n("voice.participant.spotlight");
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
      !this.isCurrentUser &&
      !this.participantIsSpeakerOrMod
    );
  }

  get canDemoteToListener() {
    return (
      this.canManageRoom &&
      this.isStageRoom &&
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
      ? i18n("voice.stage.lower_hand")
      : i18n("voice.stage.raise_hand");
  }

  get muteLabel() {
    return this.isMuted
      ? i18n("voice.participant.unmute")
      : i18n("voice.participant.mute");
  }

  get muteIcon() {
    return this.isMuted ? "volume-xmark" : "volume-high";
  }

  get micIcon() {
    return this.voiceWebrtc.audioEnabled ? "microphone" : "microphone-slash";
  }

  get micLabel() {
    return this.voiceWebrtc.audioEnabled
      ? i18n("voice.room.mic_on")
      : i18n("voice.room.mic_off");
  }

  get deafenIcon() {
    return this.voiceWebrtc.deafened ? "volume-xmark" : "volume-high";
  }

  get deafenLabel() {
    return this.voiceWebrtc.deafened
      ? i18n("voice.room.deafen_off")
      : i18n("voice.room.deafen_on");
  }

  get isPttEnabled() {
    return this.voiceWebrtc.pttEnabled;
  }

  get pttToggleLabel() {
    return this.isPttEnabled
      ? i18n("voice.ptt.disable")
      : i18n("voice.ptt.enable");
  }

  get pttKeyLabel() {
    return i18n("voice.ptt.configure_key", {
      key: humanKeyName(this.voiceWebrtc.pttKey),
    });
  }

  get micDisabledByPtt() {
    return this.isCurrentUser && this.isPttEnabled;
  }

  get showAutoStatusToggle() {
    return this.isCurrentUser && this.siteSettings.voice_auto_status_enabled;
  }

  get autoStatusLabel() {
    return this.voiceWebrtc.autoStatusEnabled
      ? i18n("voice.status.auto_update_on")
      : i18n("voice.status.auto_update_off");
  }

  @action
  onVolumeChange(event) {
    this.volume = parseInt(event.target.value, 10);
    this.voiceWebrtc.setParticipantVolume(
      this.room.id,
      this.participant.id,
      this.volume / 100
    );
  }

  @action
  toggleMute() {
    this.isMuted = this.voiceWebrtc.toggleParticipantMute(
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
      await ajax(`/voice/rooms/${this.room.id}/kick`, {
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
        flagTarget: new VoiceFlag(this.room),
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
    this.voiceWebrtc.toggleMute();
  }

  @action
  toggleDeafen() {
    this.voiceWebrtc.toggleDeafen();
  }

  @action
  toggleAutoStatus() {
    this.voiceWebrtc.toggleAutoStatus();
  }

  @action
  openVoiceSettings() {
    this.args.close();
    this.modal.show(VoiceVoiceSettingsModal);
  }

  @action
  togglePtt() {
    if (this.isPttEnabled) {
      this.voiceWebrtc.disablePtt();
    } else {
      this.voiceWebrtc.enablePtt();
    }
  }

  @action
  openKeyCapture() {
    this.showKeyCapture = true;
  }

  @action
  onKeyCaptureConfirm(keyCode) {
    this.voiceWebrtc.setPttKey(keyCode);
    this.showKeyCapture = false;
  }

  @action
  onKeyCaptureCancel() {
    this.showKeyCapture = false;
  }

  @action
  async toggleRaiseHand() {
    try {
      await ajax(`/voice/rooms/${this.room.id}/request_to_speak`, {
        type: this.handRaised ? "DELETE" : "POST",
        data: {
          participant_session_id: this.voiceWebrtc.participantSessionIdFor(
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
      await ajax(`/voice/rooms/${this.room.id}/request_to_speak`, {
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
      await ajax(`/voice/rooms/${this.room.id}/memberships`, {
        type: "POST",
        data: { user_id: this.participant.id, role: newRole },
      });
      this.args.close();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <DDropdownMenu class="voice-participant-sidebar-context-menu" as |dropdown|>
      {{#if this.canSpotlight}}
        <dropdown.item>
          <DButton
            @action={{this.toggleSpotlight}}
            @icon="person-chalkboard"
            @translatedLabel={{this.spotlightLabel}}
            @translatedTitle={{this.spotlightLabel}}
            @ariaPressed={{this.isSpotlighted}}
            class="voice-participant-sidebar-context-menu__spotlight-btn"
          />
        </dropdown.item>
      {{/if}}
      {{#if this.isCurrentUser}}
        {{#unless this.isListenerInStage}}
          <dropdown.item>
            <DButton
              @action={{this.toggleMic}}
              @icon={{this.micIcon}}
              @translatedLabel={{this.micLabel}}
              @translatedTitle={{if
                this.micDisabledByPtt
                (i18n "voice.ptt.controlled_by_ptt")
                this.micLabel
              }}
              @disabled={{this.micDisabledByPtt}}
              class="voice-participant-sidebar-context-menu__mic-btn
                {{if this.micDisabledByPtt '--disabled-by-ptt'}}"
            />
            {{#if this.micDisabledByPtt}}
              <span
                class="voice-participant-sidebar-context-menu__ptt-hint"
              >{{i18n "voice.ptt.controlled_by_ptt"}}</span>
            {{/if}}
          </dropdown.item>
        {{/unless}}
        <dropdown.item>
          <DButton
            @action={{this.toggleDeafen}}
            @icon={{this.deafenIcon}}
            @translatedLabel={{this.deafenLabel}}
            @translatedTitle={{this.deafenLabel}}
            class="voice-participant-sidebar-context-menu__deafen-btn"
          />
        </dropdown.item>
        {{#unless this.isListenerInStage}}
          <dropdown.item>
            <DButton
              @action={{this.togglePtt}}
              @icon={{if this.isPttEnabled "walkie-talkie" "walkie-talkie"}}
              @translatedLabel={{this.pttToggleLabel}}
              @translatedTitle={{this.pttToggleLabel}}
              class="voice-participant-sidebar-context-menu__ptt-btn
                {{if this.isPttEnabled '--active'}}"
            />
          </dropdown.item>
          {{#if this.isPttEnabled}}
            <dropdown.item>
              {{#if this.showKeyCapture}}
                <VoicePttKeyCapture
                  @onConfirm={{this.onKeyCaptureConfirm}}
                  @onCancel={{this.onKeyCaptureCancel}}
                />
              {{else}}
                <DButton
                  @action={{this.openKeyCapture}}
                  @icon="keyboard"
                  @translatedLabel={{this.pttKeyLabel}}
                  @translatedTitle={{this.pttKeyLabel}}
                  class="voice-participant-sidebar-context-menu__ptt-key-btn"
                />
              {{/if}}
            </dropdown.item>
          {{/if}}
        {{/unless}}
        <dropdown.item>
          <DButton
            @action={{this.openVoiceSettings}}
            @icon="gear"
            @label="voice.voice_settings.open"
            @title="voice.voice_settings.open"
            class="voice-participant-sidebar-context-menu__voice-settings-btn"
          />
        </dropdown.item>
        {{#if this.showAutoStatusToggle}}
          <dropdown.item>
            <DButton
              @action={{this.toggleAutoStatus}}
              @icon={{if
                this.voiceWebrtc.autoStatusEnabled
                "square-check"
                "far-square"
              }}
              @translatedLabel={{this.autoStatusLabel}}
              @translatedTitle={{this.autoStatusLabel}}
              class="voice-participant-sidebar-context-menu__auto-status-btn"
            />
          </dropdown.item>
        {{/if}}
        {{#if this.isListenerInStage}}
          <dropdown.item>
            <DButton
              @action={{this.toggleRaiseHand}}
              @icon="hand"
              @translatedLabel={{this.raiseHandLabel}}
              @translatedTitle={{this.raiseHandLabel}}
              class="voice-participant-sidebar-context-menu__raise-hand-btn
                {{if this.handRaised '--active'}}"
            />
          </dropdown.item>
          <dropdown.item>
            <span
              class="voice-participant-sidebar-context-menu__stage-hint"
            >{{i18n "voice.room.listeners_cannot_unmute"}}</span>
          </dropdown.item>
        {{/if}}
      {{else}}
        {{#if this.participantIsSpeakerOrMod}}
          <dropdown.item class="voice-participant-sidebar-context-menu__volume">
            <label class="voice-participant-sidebar-context-menu__volume-label">
              {{i18n "voice.participant.volume"}}
            </label>
            <input
              type="range"
              min="0"
              max="100"
              value={{this.volume}}
              class="voice-participant-sidebar-context-menu__volume-slider"
              {{on "input" this.onVolumeChange}}
            />
          </dropdown.item>
          <dropdown.item>
            <DButton
              @action={{this.toggleMute}}
              @icon={{this.muteIcon}}
              @translatedLabel={{this.muteLabel}}
              @translatedTitle={{this.muteLabel}}
              class="voice-participant-sidebar-context-menu__mute-btn"
            />
          </dropdown.item>
        {{else if (not this.isStageRoom)}}
          <dropdown.item class="voice-participant-sidebar-context-menu__volume">
            <label class="voice-participant-sidebar-context-menu__volume-label">
              {{i18n "voice.participant.volume"}}
            </label>
            <input
              type="range"
              min="0"
              max="100"
              value={{this.volume}}
              class="voice-participant-sidebar-context-menu__volume-slider"
              {{on "input" this.onVolumeChange}}
            />
          </dropdown.item>
          <dropdown.item>
            <DButton
              @action={{this.toggleMute}}
              @icon={{this.muteIcon}}
              @translatedLabel={{this.muteLabel}}
              @translatedTitle={{this.muteLabel}}
              class="voice-participant-sidebar-context-menu__mute-btn"
            />
          </dropdown.item>
        {{/if}}
        {{#if this.canPromoteToSpeaker}}
          <dropdown.item>
            <DButton
              @action={{this.promoteToSpeaker}}
              @icon="microphone"
              @label="voice.stage.make_speaker"
              @title="voice.stage.make_speaker"
              class="voice-participant-sidebar-context-menu__promote-btn"
            />
          </dropdown.item>
        {{/if}}
        {{#if this.canDemoteToListener}}
          <dropdown.item>
            <DButton
              @action={{this.demoteToListener}}
              @icon="volume-xmark"
              @label="voice.stage.move_to_listeners"
              @title="voice.stage.move_to_listeners"
              class="voice-participant-sidebar-context-menu__demote-btn"
            />
          </dropdown.item>
        {{/if}}
        {{#if this.canDismissRequest}}
          <dropdown.item>
            <DButton
              @action={{this.dismissRequest}}
              @icon="xmark"
              @label="voice.stage.dismiss_request_menu"
              @title="voice.stage.dismiss_request_menu"
              class="voice-participant-sidebar-context-menu__dismiss-request-btn"
            />
          </dropdown.item>
        {{/if}}
        {{#if this.canFlag}}
          <dropdown.item>
            <DButton
              @action={{this.flag}}
              @icon="flag"
              @label="voice.participant.flag"
              @title="voice.participant.flag"
              class="voice-participant-sidebar-context-menu__flag-btn"
            />
          </dropdown.item>
        {{/if}}
        {{#if this.canKick}}
          <dropdown.item>
            <DButton
              @action={{this.kick}}
              @icon="right-from-bracket"
              @label="voice.participant.kick"
              @title="voice.participant.kick"
              class="voice-participant-sidebar-context-menu__kick-btn btn-danger"
            />
          </dropdown.item>
        {{/if}}
      {{/if}}
    </DDropdownMenu>
  </template>
}
