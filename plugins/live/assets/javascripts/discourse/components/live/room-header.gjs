import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { optionalRequire } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import roomIcon, { roomBadge } from "../../lib/live/room-icon.js";
import LiveRoomInfoModal from "../modal/live-room-info.gjs";
import LiveRecordingBadge from "./recording-badge.gjs";
import LiveTranscriptBadge from "./transcript-badge.gjs";

const RoomMeta = <template>
  <LiveRecordingBadge @room={{@room}} />
  <LiveTranscriptBadge @room={{@room}} />
  {{#if @participantCountLabel}}
    <span class="live-room-header__participants">
      {{@participantCountLabel}}
    </span>
  {{/if}}
</template>;

const RoomTitle = <template>
  <div class="live-room-header__title">
    <h1 class="live-room-header__name">
      <span class="live-room-header__icon">
        {{dIcon @icon}}
        {{#if @badge}}
          {{dIcon @badge class="live-room-header__restricted-icon"}}
        {{/if}}
      </span>
      <DButton
        class="btn-transparent live-room-header__info-trigger"
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
  {{#if @canOpenChat}}
    <DButton
      class="btn-transparent live-room-header__open-chat"
      @action={{@onOpenChat}}
      @ariaLabel="live.chat.open"
      @icon="comment"
      @title="live.chat.open"
    />
  {{/if}}
</template>;

export default class LiveRoomHeader extends Component {
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
    return i18n("live.room_page.participant_count", { count });
  }

  @action
  openRoomInfo() {
    this.modal.show(LiveRoomInfoModal, { model: { room: this.args.room } });
  }

  <template>
    <header class="live-room-header">
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
              @onOpenChat={{@onOpenChat}}
              @room={{@room}}
            />
          </navbar.Actions>
        </this.chatNavbar>
      {{else}}
        <div class="live-room-header__fallback">
          <RoomTitle
            @badge={{this.badge}}
            @icon={{this.icon}}
            @onOpenInfo={{this.openRoomInfo}}
            @participantCountLabel={{this.participantCountLabel}}
            @room={{@room}}
          />
          <div class="live-room-header__actions">
            <RoomActions
              @canOpenChat={{@canOpenChat}}
              @onOpenChat={{@onOpenChat}}
              @room={{@room}}
            />
          </div>
        </div>
      {{/if}}
    </header>
  </template>
}
