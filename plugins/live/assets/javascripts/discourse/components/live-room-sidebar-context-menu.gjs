import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { clipboardCopy } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";
import LiveInviteAgentButton from "./live-invite-agent-button.gjs";
import LiveInviteUsersModal from "./modal/live-invite-users.gjs";
import LiveRoomInfoModal from "./modal/live-room-info.gjs";

export default class LiveRoomSidebarContextMenu extends Component {
  @service modal;
  @service liveWebrtc;
  @service router;
  @service toasts;

  get room() {
    return this.args.data.room;
  }

  get isConnected() {
    return this.liveWebrtc.connectionStateFor(this.room.id) === "connected";
  }

  @action
  openRoomPage() {
    this.router.transitionTo("live-room", this.room.slug);
    this.args.close();
  }

  @action
  openRoomInfo() {
    this.modal.show(LiveRoomInfoModal, { model: { room: this.room } });
    this.args.close();
  }

  @action
  openInviteModal() {
    this.modal.show(LiveInviteUsersModal, { model: { room: this.room } });
    this.args.close();
  }

  @action
  copyRoomLink() {
    const url = this.router.urlFor("live-room", this.room.slug);
    clipboardCopy(new URL(url, window.location.origin).href);
    this.toasts.success({
      duration: "short",
      data: { message: i18n("live.room.link_copied") },
    });
    this.args.close();
  }

  @action
  editRoom() {
    this.modal.show(LiveRoomInfoModal, {
      model: { room: this.room, isEditing: true },
    });
    this.args.close();
  }

  @action
  toggleCallWidget() {
    this.liveWebrtc.toggleCallWidgetHidden();
    this.args.close();
  }

  @action
  leaveRoom() {
    this.liveWebrtc.leave(this.room);
    this.args.close();
  }

  <template>
    <DDropdownMenu class="live-room-sidebar-context-menu" as |dropdown|>
      <LiveInviteAgentButton
        @closeMenu={{@close}}
        @item={{dropdown.item}}
        @room={{this.room}}
      />
      <dropdown.item>
        <DButton
          class="live-room-sidebar-context-menu__open-page"
          @action={{this.openRoomPage}}
          @icon="expand"
          @label="live.room.open_page"
          @title="live.room.open_page"
        />
      </dropdown.item>
      <dropdown.item>
        <DButton
          class="live-room-sidebar-context-menu__room-info"
          @action={{this.openRoomInfo}}
          @icon="circle-info"
          @label="live.room.info"
          @title="live.room.info"
        />
      </dropdown.item>
      {{#if this.room.can_invite}}
        <dropdown.item>
          <DButton
            class="live-room-sidebar-context-menu__invite"
            @action={{this.openInviteModal}}
            @icon="user-plus"
            @label="live.invite.menu"
            @title="live.invite.menu"
          />
        </dropdown.item>
      {{/if}}
      <dropdown.item>
        <DButton
          class="live-room-sidebar-context-menu__copy-link"
          @action={{this.copyRoomLink}}
          @icon="link"
          @label="live.room.copy_link"
          @title="live.room.copy_link"
        />
      </dropdown.item>
      {{#if this.room.can_manage}}
        <dropdown.item>
          <DButton
            class="live-room-sidebar-context-menu__edit-room"
            @action={{this.editRoom}}
            @icon="pencil"
            @label="live.room.edit"
            @title="live.room.edit"
          />
        </dropdown.item>
      {{/if}}
      {{#if this.isConnected}}
        <dropdown.item>
          <DButton
            class="live-room-sidebar-context-menu__toggle-widget"
            @action={{this.toggleCallWidget}}
            @icon={{if this.liveWebrtc.callWidgetHidden "eye" "eye-slash"}}
            @label={{if
              this.liveWebrtc.callWidgetHidden
              "live.widget.show"
              "live.widget.hide"
            }}
            @title={{if
              this.liveWebrtc.callWidgetHidden
              "live.widget.show"
              "live.widget.hide"
            }}
          />
        </dropdown.item>
        <dropdown.item>
          <DButton
            class="live-room-sidebar-context-menu__leave-room --danger"
            @action={{this.leaveRoom}}
            @icon="phone-slash"
            @label="live.room.leave"
            @title="live.room.leave"
          />
        </dropdown.item>
      {{/if}}
    </DDropdownMenu>
  </template>
}
