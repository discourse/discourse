import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";
import { formatMuteEnd } from "discourse/plugins/chat/discourse/lib/chat-mute-durations";
import ChatChannelSidebarContextMuteSubmenu from "./chat-channel-sidebar-context-mute-submenu.gjs";
import ChatChannelSidebarContextNotificationSubmenu from "./chat-channel-sidebar-context-notification-submenu.gjs";

export default class ChatChannelSidebarContextMenu extends Component {
  @service chatApi;
  @service chat;
  @service menu;
  @service router;
  @service chatChannelsManager;
  @service currentUser;

  get channel() {
    return this.args.data.channel;
  }

  get currentUserMembership() {
    return this.channel?.currentUserMembership;
  }

  get isTogglingStarred() {
    return this.chatChannelsManager.isUpdatingStarred(this.channel);
  }

  get starIcon() {
    return this.currentUserMembership?.starred ? "star" : "far-star";
  }

  get starLabel() {
    return this.currentUserMembership?.starred
      ? "chat.channel_settings.unstar_channel"
      : "chat.channel_settings.star_channel";
  }

  get mutedUntil() {
    if (!this.currentUserMembership?.mutedUntil) {
      return;
    }

    return formatMuteEnd(
      this.currentUserMembership.mutedUntil,
      this.currentUser
    );
  }

  get leaveLabel() {
    return this.channel.isDirectMessageChannel
      ? "chat.channel_settings.close_channel"
      : "chat.channel_settings.leave_channel";
  }

  @action
  async toggleStarred() {
    const channel = this.channel;
    const menuIdentifier = channel.isDirectMessageChannel
      ? "chat-direct-message-channel-menu"
      : "chat-channel-menu";
    const menu = this.menu;

    await this.chatChannelsManager.toggleStarred(channel, {
      beforeUpdate: () => menu.close(menuIdentifier),
    });
  }

  @action
  async leaveChannel() {
    try {
      if (this.channel.isDirectMessageChannel) {
        await this.chat.unfollowChannel(this.channel);
      } else {
        await this.chatApi.leaveChannel(this.channel.id);
      }
      this.currentUser.custom_fields.last_chat_channel_id = null;

      this.args.close();
      this.chatChannelsManager.remove(this.channel);

      if (this.chatChannelsManager.publicMessageChannels.length) {
        return this.router.transitionTo(
          "chat.channel",
          ...this.chatChannelsManager.publicMessageChannels[0].routeModels
        );
      } else if (this.chatChannelsManager.directMessageChannels.length) {
        return this.router.transitionTo(
          "chat.channel",
          ...this.chatChannelsManager.directMessageChannels[0].routeModels
        );
      } else {
        return this.router.transitionTo("chat.browse");
      }
    } catch (err) {
      popupAjaxError(err);
    }
  }

  @action
  async unmuteChannel() {
    try {
      const result =
        await this.chatApi.updateCurrentUserChannelNotificationsSettings(
          this.channel.id,
          { muted: false }
        );
      this.currentUserMembership.muted = result.membership.muted;
      this.currentUserMembership.mutedUntil = null;
    } catch (err) {
      popupAjaxError(err);
    } finally {
      this.args.close();
    }
  }

  @action
  async navigateToSettings() {
    try {
      await this.router.transitionTo(
        "chat.channel.info.settings",
        ...this.channel.routeModels
      );
    } finally {
      this.args.close();
    }
  }

  @action
  openNotificationSettings(_actionParam, event) {
    this.menu.show(event.target, {
      identifier: "chat-channel-menu-notification-submenu",
      component: ChatChannelSidebarContextNotificationSubmenu,
      modalForMobile: true,
      placement: "right-start",
      offset: { mainAxis: 10, crossAxis: -5 },
      data: { channel: this.channel },
      onClose: () => this.args.close(),
    });
  }

  @action
  openMuteSettings(_actionParam, event) {
    this.menu.show(event.target, {
      identifier: "chat-channel-menu-mute-submenu",
      component: ChatChannelSidebarContextMuteSubmenu,
      modalForMobile: true,
      placement: "right-start",
      offset: { mainAxis: 10, crossAxis: -5 },
      data: { channel: this.channel },
      onClose: () => this.args.close(),
    });
  }

  <template>
    <DDropdownMenu class="chat-channel-sidebar-link-menu" as |dropdown|>
      <dropdown.item>
        <DButton
          class="chat-channel-sidebar-link-menu__open-notification-settings"
          @action={{this.openNotificationSettings}}
          @forwardEvent={{true}}
          @icon="bell"
          @label="chat.channel_settings.notification_settings_context"
          @suffixIcon="angle-right"
          @title="chat.channel_settings.notification_settings_context"
        />
      </dropdown.item>
      <dropdown.item>
        {{#if this.currentUserMembership.muted}}
          <DButton
            class="chat-channel-sidebar-link-menu__unmute-channel"
            @action={{this.unmuteChannel}}
            @icon="bell"
            @label="chat.settings.unmute"
          >
            {{#if this.mutedUntil}}
              <span class="chat-channel-sidebar-link-menu__muted-until">
                {{i18n "chat.settings.muted_until_hint" until=this.mutedUntil}}
              </span>
            {{/if}}
          </DButton>
        {{else}}
          <DButton
            class="chat-channel-sidebar-link-menu__open-mute-settings"
            @action={{this.openMuteSettings}}
            @forwardEvent={{true}}
            @icon="bell-slash"
            @label="chat.settings.mute"
            @suffixIcon="angle-right"
            @title="chat.settings.mute"
          />
        {{/if}}
      </dropdown.item>
      <dropdown.item>
        <DButton
          class="chat-channel-sidebar-link-menu__channel-settings"
          @action={{this.navigateToSettings}}
          @icon="gear"
          @label="chat.channel_settings.title"
          @title="chat.channel_settings.title"
        />
      </dropdown.item>
      <dropdown.item>
        <DButton
          class="chat-channel-sidebar-link-menu__star-channel"
          @action={{this.toggleStarred}}
          @disabled={{this.isTogglingStarred}}
          @icon={{this.starIcon}}
          @label={{this.starLabel}}
          @title={{this.starLabel}}
        />
      </dropdown.item>
      <dropdown.item>
        <DButton
          class="chat-channel-sidebar-link-menu__leave-channel --danger"
          @action={{this.leaveChannel}}
          @icon="xmark"
          @label={{this.leaveLabel}}
          @title={{this.leaveLabel}}
        />
      </dropdown.item>
    </DDropdownMenu>
  </template>
}
