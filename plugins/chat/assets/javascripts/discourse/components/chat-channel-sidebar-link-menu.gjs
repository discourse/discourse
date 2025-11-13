import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseLater from "discourse/lib/later";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

class ChatChannelSidebarMenuNotificationSubmenu extends Component {
  @service chatApi;

  @action
  async changePushNotifications(setting) {
    try {
      const result =
        await this.chatApi.updateCurrentUserChannelNotificationsSettings(
          this.args.data.channel.id,
          {
            notification_level: setting,
          }
        );
      this.args.data.channel.currentUserMembership.notificationLevel =
        result.membership.notification_level;
    } catch (err) {
      popupAjaxError(err);
    }
    this.args.close();
  }

  @action
  async toggleMuteChannel() {
    try {
      const result =
        await this.chatApi.updateCurrentUserChannelNotificationsSettings(
          this.args.data.channel.id,
          {
            muted: !this.args.data.channel.currentUserMembership.muted,
          }
        );
      this.args.data.channel.currentUserMembership.muted =
        result.membership.muted;
    } catch (err) {
      popupAjaxError(err);
    }
    this.args.close();
  }

  <template>
    <DropdownMenu as |dropdown|>
      <dropdown.item class="--text-only">
        {{i18n "chat.settings.notification_level"}}...
      </dropdown.item>

      <dropdown.item>
        <DButton
          @action={{this.changePushNotifications "never"}}
          @icon={{if
            (eq @data.channel.currentUserMembership.notificationLevel "never")
            "check"
            ""
          }}
          @label="chat.notification_levels.never"
          @title="chat.notification_levels.never"
          class="chat-channel-sidebar-link-menu__notification-level-never"
        />
      </dropdown.item>

      <dropdown.item>
        <DButton
          @action={{this.changePushNotifications "mention"}}
          @icon={{if
            (eq @data.channel.currentUserMembership.notificationLevel "mention")
            "check"
            ""
          }}
          @label="chat.notification_levels.mention"
          @title="chat.notification_levels.mention"
          class="chat-channel-sidebar-link-menu__notification-level-mention"
        />
      </dropdown.item>

      <dropdown.item>
        <DButton
          @action={{this.changePushNotifications "always"}}
          @icon={{if
            (eq @data.channel.currentUserMembership.notificationLevel "always")
            "check"
            ""
          }}
          @label="chat.notification_levels.always"
          @title="chat.notification_levels.always"
          class="chat-channel-sidebar-link-menu__notification-level-always"
        />
      </dropdown.item>

      <dropdown.divider />

      <dropdown.item>
        <DButton
          @action={{this.toggleMuteChannel}}
          @icon={{if
            @data.channel.currentUserMembership.muted
            "bell-slash"
            "bell"
          }}
          @label={{if
            @data.channel.currentUserMembership.muted
            "chat.settings.unmute"
            "chat.settings.mute"
          }}
          @title={{if
            @data.channel.currentUserMembership.muted
            "chat.settings.unmute"
            "chat.settings.mute"
          }}
          class="chat-channel-sidebar-link-menu__mute-channel"
        />
      </dropdown.item>
    </DropdownMenu>
  </template>
}

export default class ChatChannelSidebarLinkMenu extends Component {
  @service chatApi;
  @service menu;

  get channel() {
    return this.args.data.channel;
  }

  get currentUserMembership() {
    return this.channel?.currentUserMembership;
  }

  @action
  leaveChannel() {
    try {
      this.chatApi.leaveChannel(this.args.data.channel.id);
    } catch (err) {
      popupAjaxError(err);
    }
    this.args.close();
  }

  @action
  closeAfterNav() {
    discourseLater(() => {
      this.args.close();
    }, 100);
  }

  @action
  openNotificationSettings(_, event) {
    this.menu.show(event.target, {
      identifier: "chat-channel-menu-notification-submenu",
      component: ChatChannelSidebarMenuNotificationSubmenu,
      modalForMobile: true,
      placement: "right-start",
      data: { channel: this.channel },
      onClose: () => {
        this.args.close();
      },
    });
  }

  <template>
    <DropdownMenu as |dropdown|>
      <dropdown.item>
        <DButton
          @action={{this.openNotificationSettings}}
          @forwardEvent={{true}}
          @icon="bell"
          @suffixIcon="angle-right"
          @label="chat.channel_settings.notification_settings"
          @title="chat.channel_settings.notification_settings"
          class="chat-channel-sidebar-link-menu__open-notification-settings"
        />
      </dropdown.item>
      <dropdown.item>
        <DButton
          {{on "click" this.closeAfterNav}}
          @route="chat.channel.info.settings"
          @routeModels={{this.channel}}
          @icon="gear"
          @label="chat.channel_settings.title"
          @title="chat.channel_settings.title"
          class="chat-channel-sidebar-link-menu__channel-settings"
        />
      </dropdown.item>
      <dropdown.item>
        <DButton
          @action={{this.leaveChannel}}
          @icon="xmark"
          @label="chat.channel_settings.leave_channel"
          @title="chat.channel_settings.leave_channel"
          class="chat-channel-sidebar-link-menu__leave-channel btn-danger"
        />
      </dropdown.item>
    </DropdownMenu>
  </template>
}
