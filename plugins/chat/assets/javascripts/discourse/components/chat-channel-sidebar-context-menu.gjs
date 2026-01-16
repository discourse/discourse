import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ChatChannelSidebarContextNotificationSubmenu from "./chat-channel-sidebar-context-notification-submenu";

export default class ChatChannelSidebarContextMenu extends Component {
  @service chatApi;
  @service chat;
  @service menu;
  @service router;
  @service chatChannelsManager;
  @service currentUser;

  @tracked isTogglingStarred;

  get channel() {
    return this.args.data.channel;
  }

  get currentUserMembership() {
    return this.channel?.currentUserMembership;
  }

  get starIcon() {
    return this.currentUserMembership?.starred ? "star" : "far-star";
  }

  get starLabel() {
    return this.currentUserMembership?.starred
      ? "chat.channel_settings.unstar_channel"
      : "chat.channel_settings.star_channel";
  }

  @action
  async toggleStarred() {
    if (!this.currentUserMembership || this.isTogglingStarred) {
      return;
    }

    this.isTogglingStarred = true;
    const previousValue = this.currentUserMembership.starred;
    const newValue = !previousValue;

    this.currentUserMembership.starred = newValue;

    try {
      await this.chatApi.updateCurrentUserChannelMembership(this.channel.id, {
        starred: newValue,
      });
      this.args.close();
    } catch (err) {
      this.currentUserMembership.starred = previousValue;
      popupAjaxError(err);
    } finally {
      this.isTogglingStarred = false;
    }
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
      data: { channel: this.channel },
      onClose: () => this.args.close(),
    });
  }

  <template>
    <DropdownMenu class="chat-channel-sidebar-link-menu" as |dropdown|>
      <dropdown.item>
        <DButton
          @action={{this.openNotificationSettings}}
          @forwardEvent={{true}}
          @icon="bell"
          @suffixIcon="angle-right"
          @label="chat.channel_settings.notification_settings_context"
          @title="chat.channel_settings.notification_settings_context"
          class="chat-channel-sidebar-link-menu__open-notification-settings"
        />
      </dropdown.item>
      <dropdown.item>
        <DButton
          @action={{this.navigateToSettings}}
          @icon="gear"
          @label="chat.channel_settings.title"
          @title="chat.channel_settings.title"
          class="chat-channel-sidebar-link-menu__channel-settings"
        />
      </dropdown.item>
      <dropdown.item>
        <DButton
          @action={{this.toggleStarred}}
          @disabled={{this.isTogglingStarred}}
          @icon={{this.starIcon}}
          @label={{this.starLabel}}
          @title={{this.starLabel}}
          class="chat-channel-sidebar-link-menu__star-channel"
        />
      </dropdown.item>
      <dropdown.item>
        <DButton
          @action={{this.leaveChannel}}
          @icon="xmark"
          @label="chat.channel_settings.leave_channel"
          @title="chat.channel_settings.leave_channel"
          class="chat-channel-sidebar-link-menu__leave-channel --danger"
        />
      </dropdown.item>
    </DropdownMenu>
  </template>
}
