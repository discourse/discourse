import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { clipboardCopy } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";
import VoiceInviteUsersModal from "./modal/voice-invite-users";
import VoiceRoomInfoModal from "./modal/voice-room-info";

export default class VoiceRoomSidebarContextMenu extends Component {
  @service modal;
  @service voiceWebrtc;
  @service router;
  @service toasts;

  get room() {
    return this.args.data.room;
  }

  get isConnected() {
    return this.voiceWebrtc.connectionStateFor(this.room.id) === "connected";
  }

  @action
  openRoomPage() {
    this.router.transitionTo("voice-room", this.room.slug);
    this.args.close();
  }

  @action
  openRoomInfo() {
    this.modal.show(VoiceRoomInfoModal, { model: { room: this.room } });
    this.args.close();
  }

  @action
  openInviteModal() {
    this.modal.show(VoiceInviteUsersModal, { model: { room: this.room } });
    this.args.close();
  }

  @action
  copyRoomLink() {
    const url = this.router.urlFor("voice-room", this.room.slug);
    clipboardCopy(new URL(url, window.location.origin).href);
    this.toasts.success({
      duration: "short",
      data: { message: i18n("voice.room.link_copied") },
    });
    this.args.close();
  }

  @action
  editRoom() {
    this.modal.show(VoiceRoomInfoModal, {
      model: { room: this.room, isEditing: true },
    });
    this.args.close();
  }

  @action
  toggleCallWidget() {
    this.voiceWebrtc.toggleCallWidgetHidden();
    this.args.close();
  }

  @action
  leaveRoom() {
    this.voiceWebrtc.leave(this.room);
    this.args.close();
  }

  <template>
    <DDropdownMenu class="voice-room-sidebar-context-menu" as |dropdown|>
      <dropdown.item>
        <DButton
          @action={{this.openRoomPage}}
          @icon="expand"
          @label="voice.room.open_page"
          @title="voice.room.open_page"
          class="voice-room-sidebar-context-menu__open-page"
        />
      </dropdown.item>
      <dropdown.item>
        <DButton
          @action={{this.openRoomInfo}}
          @icon="circle-info"
          @label="voice.room.info"
          @title="voice.room.info"
          class="voice-room-sidebar-context-menu__room-info"
        />
      </dropdown.item>
      {{#if this.room.can_invite}}
        <dropdown.item>
          <DButton
            @action={{this.openInviteModal}}
            @icon="user-plus"
            @label="voice.invite.menu"
            @title="voice.invite.menu"
            class="voice-room-sidebar-context-menu__invite"
          />
        </dropdown.item>
      {{/if}}
      <dropdown.item>
        <DButton
          @action={{this.copyRoomLink}}
          @icon="link"
          @label="voice.room.copy_link"
          @title="voice.room.copy_link"
          class="voice-room-sidebar-context-menu__copy-link"
        />
      </dropdown.item>
      {{#if this.room.can_manage}}
        <dropdown.item>
          <DButton
            @action={{this.editRoom}}
            @icon="pencil"
            @label="voice.room.edit"
            @title="voice.room.edit"
            class="voice-room-sidebar-context-menu__edit-room"
          />
        </dropdown.item>
      {{/if}}
      {{#if this.isConnected}}
        <dropdown.item>
          <DButton
            @action={{this.toggleCallWidget}}
            @icon={{if this.voiceWebrtc.callWidgetHidden "eye" "eye-slash"}}
            @label={{if
              this.voiceWebrtc.callWidgetHidden
              "voice.widget.show"
              "voice.widget.hide"
            }}
            @title={{if
              this.voiceWebrtc.callWidgetHidden
              "voice.widget.show"
              "voice.widget.hide"
            }}
            class="voice-room-sidebar-context-menu__toggle-widget"
          />
        </dropdown.item>
        <dropdown.item>
          <DButton
            @action={{this.leaveRoom}}
            @icon="phone-slash"
            @label="voice.room.leave"
            @title="voice.room.leave"
            class="voice-room-sidebar-context-menu__leave-room --danger"
          />
        </dropdown.item>
      {{/if}}
    </DDropdownMenu>
  </template>
}
