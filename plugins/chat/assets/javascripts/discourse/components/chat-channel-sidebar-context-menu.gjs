import Component from "@glimmer/component";
import { action } from "@ember/object";
import { trackedSet } from "@ember/reactive/collections";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import ChatChannelSidebarContextNotificationSubmenu from "./chat-channel-sidebar-context-notification-submenu";

const pendingStarredUpdates = trackedSet();

function restoreSidebarScrollPosition(sidebar, scrollTop) {
  if (!sidebar || scrollTop === undefined) {
    return;
  }

  // A moved active link schedules its own scroll after insertion.
  schedule("afterRender", () => {
    schedule("afterRender", () => {
      if (sidebar.isConnected) {
        sidebar.scrollTop = scrollTop;
      }
    });
  });
}

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
    return pendingStarredUpdates.has(this.currentUserMembership);
  }

  get starIcon() {
    return this.currentUserMembership?.starred ? "star" : "far-star";
  }

  get starLabel() {
    return this.currentUserMembership?.starred
      ? "chat.channel_settings.unstar_channel"
      : "chat.channel_settings.star_channel";
  }

  get leaveLabel() {
    return this.channel.isDirectMessageChannel
      ? "chat.channel_settings.close_channel"
      : "chat.channel_settings.leave_channel";
  }

  @action
  async toggleStarred() {
    const channel = this.channel;
    const membership = this.currentUserMembership;

    if (!membership || pendingStarredUpdates.has(membership)) {
      return;
    }

    pendingStarredUpdates.add(membership);
    const previousValue = membership.starred;
    const newValue = !previousValue;
    const menuIdentifier = channel.isDirectMessageChannel
      ? "chat-direct-message-channel-menu"
      : "chat-channel-menu";
    const sidebar = this.menu
      .getByIdentifier(menuIdentifier)
      ?.triggerElement?.closest(".sidebar-sections");
    const sidebarScrollTop = sidebar?.scrollTop;
    const chatApi = this.chatApi;
    const menu = this.menu;

    await menu.close(menuIdentifier);
    membership.starred = newValue;
    restoreSidebarScrollPosition(sidebar, sidebarScrollTop);

    try {
      await chatApi.updateCurrentUserChannelMembership(channel.id, {
        starred: newValue,
      });
    } catch (err) {
      membership.starred = previousValue;
      restoreSidebarScrollPosition(sidebar, sidebarScrollTop);
      popupAjaxError(err);
    } finally {
      pendingStarredUpdates.delete(membership);
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
      offset: { mainAxis: 10, crossAxis: -5 },
      data: { channel: this.channel },
      onClose: () => this.args.close(),
    });
  }

  <template>
    <DDropdownMenu class="chat-channel-sidebar-link-menu" as |dropdown|>
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
          @label={{this.leaveLabel}}
          @title={{this.leaveLabel}}
          class="chat-channel-sidebar-link-menu__leave-channel --danger"
        />
      </dropdown.item>
    </DDropdownMenu>
  </template>
}
