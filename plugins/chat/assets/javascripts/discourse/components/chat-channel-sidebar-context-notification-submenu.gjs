import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import concatClass from "discourse/helpers/concat-class";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class ChatChannelSidebarContextNotificationSubmenu extends Component {
  @service chatApi;

  get channel() {
    return this.args.data.channel;
  }

  @action
  isItemSelected(item) {
    if (this.channel.currentUserMembership.muted) {
      return item === "muted";
    }

    return this.channel.currentUserMembership.notificationLevel === item;
  }

  @action
  async changePushNotifications(setting) {
    try {
      const result =
        await this.chatApi.updateCurrentUserChannelNotificationsSettings(
          this.channel.id,
          {
            notification_level: setting,
          }
        );
      this.channel.currentUserMembership.notificationLevel =
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
          this.channel.id,
          {
            muted: !this.channel.currentUserMembership.muted,
          }
        );
      this.channel.currentUserMembership.muted = result.membership.muted;
    } catch (err) {
      popupAjaxError(err);
    }
    this.args.close();
  }

  <template>
    <DropdownMenu as |dropdown|>
      <dropdown.item>
        <DButton
          @action={{this.changePushNotifications "never"}}
          @label="chat.notification_levels.never"
          @title="chat.notification_levels.never"
          class={{concatClass
            "chat-channel-sidebar-link-menu__notification-level-never"
            (if (this.isItemSelected "never") "-selected")
          }}
        />
      </dropdown.item>

      <dropdown.item>
        <DButton
          @action={{this.changePushNotifications "mention"}}
          @label="chat.notification_levels.mention"
          @title="chat.notification_levels.mention"
          class={{concatClass
            "chat-channel-sidebar-link-menu__notification-level-mention"
            (if (this.isItemSelected "mention") "-selected")
          }}
        />
      </dropdown.item>

      <dropdown.item>
        <DButton
          @action={{this.changePushNotifications "always"}}
          @label="chat.notification_levels.always"
          @title="chat.notification_levels.always"
          class={{concatClass
            "chat-channel-sidebar-link-menu__notification-level-always"
            (if (this.isItemSelected "always") "-selected")
          }}
        />
      </dropdown.item>

      <dropdown.divider />

      <dropdown.item>
        <DButton
          @action={{this.toggleMuteChannel}}
          @icon={{if
            this.channel.currentUserMembership.muted
            "bell-slash"
            "bell"
          }}
          @label={{if
            this.channel.currentUserMembership.muted
            "chat.settings.unmute"
            "chat.settings.mute"
          }}
          @title={{if
            this.channel.currentUserMembership.muted
            "chat.settings.unmute"
            "chat.settings.mute"
          }}
          class={{concatClass
            "chat-channel-sidebar-link-menu__mute-channel"
            (if (this.isItemSelected "muted") "-selected")
          }}
        />
      </dropdown.item>
    </DropdownMenu>
  </template>
}
