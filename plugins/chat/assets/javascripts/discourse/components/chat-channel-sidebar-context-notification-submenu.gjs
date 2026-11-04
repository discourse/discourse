import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import {
  formatMuteEnd,
  MUTE_DURATIONS,
  mutedUntilFromNow,
} from "discourse/plugins/chat/discourse/lib/chat-mute-durations";

export default class ChatChannelSidebarContextNotificationSubmenu extends Component {
  @service chatApi;
  @service currentUser;

  muteDurations = MUTE_DURATIONS.map((duration) => ({
    ...duration,
    label: `chat.settings.mute_options.${duration.id}`,
  }));

  get channel() {
    return this.args.data.channel;
  }

  get membership() {
    return this.channel.currentUserMembership;
  }

  get mutedUntilLabel() {
    if (!this.membership.mutedUntil) {
      return;
    }

    return i18n("chat.settings.muted_until", {
      until: formatMuteEnd(this.membership.mutedUntil, this.currentUser),
    });
  }

  @action
  isItemSelected(item) {
    if (this.membership.muted) {
      return item === "muted";
    }

    return this.membership.notificationLevel === item;
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
      this.membership.notificationLevel = result.membership.notification_level;
    } catch (err) {
      popupAjaxError(err);
    }
    this.args.close();
  }

  @action
  muteFor(minutes) {
    return this.#saveMute({
      muted: true,
      muted_until: mutedUntilFromNow(minutes),
    });
  }

  @action
  toggleMuteChannel() {
    return this.#saveMute({ muted: !this.membership.muted });
  }

  async #saveMute(settings) {
    try {
      const result =
        await this.chatApi.updateCurrentUserChannelNotificationsSettings(
          this.channel.id,
          settings
        );
      this.membership.muted = result.membership.muted;
      this.membership.mutedUntil = result.membership.muted_until
        ? new Date(result.membership.muted_until)
        : null;
    } catch (err) {
      popupAjaxError(err);
    }
    this.args.close();
  }

  <template>
    <DDropdownMenu as |dropdown|>
      <dropdown.item>
        <DButton
          class={{dConcatClass
            "chat-channel-sidebar-link-menu__notification-level-never"
            (if (this.isItemSelected "never") "-selected")
          }}
          @action={{this.changePushNotifications "never"}}
          @label="chat.notification_levels.never"
          @title="chat.notification_levels.never"
        />
      </dropdown.item>

      <dropdown.item>
        <DButton
          class={{dConcatClass
            "chat-channel-sidebar-link-menu__notification-level-mention"
            (if (this.isItemSelected "mention") "-selected")
          }}
          @action={{this.changePushNotifications "mention"}}
          @label="chat.notification_levels.mention"
          @title="chat.notification_levels.mention"
        />
      </dropdown.item>

      <dropdown.item>
        <DButton
          class={{dConcatClass
            "chat-channel-sidebar-link-menu__notification-level-always"
            (if (this.isItemSelected "always") "-selected")
          }}
          @action={{this.changePushNotifications "always"}}
          @label="chat.notification_levels.always"
          @title="chat.notification_levels.always"
        />
      </dropdown.item>

      <dropdown.divider />

      {{#if this.membership.muted}}
        {{#if this.mutedUntilLabel}}
          <dropdown.subheader
            class="chat-channel-sidebar-link-menu__muted-until"
          >
            {{this.mutedUntilLabel}}
          </dropdown.subheader>
        {{/if}}

        <dropdown.item>
          <DButton
            class="chat-channel-sidebar-link-menu__mute-channel -selected"
            @action={{this.toggleMuteChannel}}
            @icon="bell"
            @label="chat.settings.unmute"
            @title="chat.settings.unmute"
          />
        </dropdown.item>
      {{else}}
        <dropdown.subheader>
          {{i18n "chat.settings.mute"}}
        </dropdown.subheader>

        {{#each this.muteDurations as |duration|}}
          <dropdown.item>
            <DButton
              class="chat-channel-sidebar-link-menu__mute-for"
              data-mute-duration={{duration.id}}
              @action={{fn this.muteFor duration.minutes}}
              @label={{duration.label}}
              @title={{duration.label}}
            />
          </dropdown.item>
        {{/each}}

        <dropdown.item>
          <DButton
            class="chat-channel-sidebar-link-menu__mute-channel"
            @action={{this.toggleMuteChannel}}
            @label="chat.settings.mute_options.until_unmuted"
            @title="chat.settings.mute_options.until_unmuted"
          />
        </dropdown.item>
      {{/if}}
    </DDropdownMenu>
  </template>
}
