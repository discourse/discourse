import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { optionalRequire } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import roomIcon, { roomBadge } from "../../lib/voice/room-icon.js";
import VoiceInviteUsersModal from "../modal/voice-invite-users.gjs";
import VoiceRecordingBadge from "./recording-badge.gjs";
import VoiceTranscriptBadge from "./transcript-badge.gjs";

const RoomMeta = <template>
  {{#if @badge}}
    {{dIcon @badge class="voice-room-header__badge"}}
  {{/if}}
  <VoiceRecordingBadge @room={{@room}} />
  <VoiceTranscriptBadge @room={{@room}} />
  {{#if @participantCountLabel}}
    <span class="voice-room-header__participants">
      {{@participantCountLabel}}
    </span>
  {{/if}}
</template>;

const RoomActions = <template>
  {{#if @room.can_invite}}
    <DButton
      class="btn-transparent voice-room-header__invite"
      @action={{@onInvite}}
      @ariaLabel="voice.invite.menu"
      @icon="user-plus"
      @title="voice.invite.menu"
    />
  {{/if}}
  {{#if @canOpenChat}}
    <DButton
      class="btn-transparent voice-room-header__open-chat"
      @action={{@onOpenChat}}
      @ariaLabel="voice.chat.open"
      @icon="comment"
      @title="voice.chat.open"
    />
  {{/if}}
</template>;

export default class VoiceRoomHeader extends Component {
  @service modal;

  chatNavbar = optionalRequire(
    "discourse/plugins/chat/discourse/components/chat/navbar"
  );

  get icon() {
    return roomIcon(this.args.room);
  }

  get badge() {
    return roomBadge(this.args.room);
  }

  get participantCountLabel() {
    const count = this.args.room.active_participants?.length;
    if (!count) {
      return null;
    }
    return i18n("voice.room_page.participant_count", { count });
  }

  @action
  openInviteModal() {
    this.modal.show(VoiceInviteUsersModal, {
      model: { room: this.args.room },
    });
  }

  <template>
    <header class="voice-room-header">
      {{#if this.chatNavbar}}
        <this.chatNavbar as |navbar|>
          <navbar.Title @icon={{this.icon}} @title={{@room.name}}>
            <RoomMeta
              @badge={{this.badge}}
              @participantCountLabel={{this.participantCountLabel}}
              @room={{@room}}
            />
          </navbar.Title>
          <navbar.Actions>
            <RoomActions
              @canOpenChat={{@canOpenChat}}
              @onInvite={{this.openInviteModal}}
              @onOpenChat={{@onOpenChat}}
              @room={{@room}}
            />
          </navbar.Actions>
        </this.chatNavbar>
      {{else}}
        <div class="voice-room-header__fallback">
          <h1 class="voice-room-header__title">
            {{dIcon this.icon}}
            {{@room.name}}
          </h1>
          <RoomMeta
            @badge={{this.badge}}
            @participantCountLabel={{this.participantCountLabel}}
            @room={{@room}}
          />
          <div class="voice-room-header__actions">
            <RoomActions
              @canOpenChat={{@canOpenChat}}
              @onInvite={{this.openInviteModal}}
              @onOpenChat={{@onOpenChat}}
              @room={{@room}}
            />
          </div>
        </div>
      {{/if}}
    </header>
  </template>
}
