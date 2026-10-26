import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { optionalRequire } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import roomIcon, { roomBadge } from "../../lib/voice/room-icon.js";
import VoiceInviteUsersModal from "../modal/voice-invite-users.gjs";
import VoiceRoomInfoModal from "../modal/voice-room-info.gjs";
import VoiceRecordingBadge from "./recording-badge.gjs";
import VoiceTranscriptBadge from "./transcript-badge.gjs";

const RoomMeta = <template>
  <VoiceRecordingBadge @room={{@room}} />
  <VoiceTranscriptBadge @room={{@room}} />
  {{#if @participantCountLabel}}
    <span class="voice-room-header__participants">
      {{@participantCountLabel}}
    </span>
  {{/if}}
</template>;

const RoomTitle = <template>
  <div class="voice-room-header__title">
    <h1 class="voice-room-header__name">
      <span class="voice-room-header__icon">
        {{dIcon @icon}}
        {{#if @badge}}
          {{dIcon @badge class="voice-room-header__restricted-icon"}}
        {{/if}}
      </span>
      <DButton
        class="btn-transparent voice-room-header__info-trigger"
        @action={{@onOpenInfo}}
        @translatedLabel={{@room.name}}
      />
    </h1>
    <RoomMeta
      @participantCountLabel={{@participantCountLabel}}
      @room={{@room}}
    />
  </div>
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
  openRoomInfo() {
    this.modal.show(VoiceRoomInfoModal, { model: { room: this.args.room } });
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
          <RoomTitle
            @badge={{this.badge}}
            @icon={{this.icon}}
            @onOpenInfo={{this.openRoomInfo}}
            @participantCountLabel={{this.participantCountLabel}}
            @room={{@room}}
          />
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
          <RoomTitle
            @badge={{this.badge}}
            @icon={{this.icon}}
            @onOpenInfo={{this.openRoomInfo}}
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
