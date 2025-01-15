import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import icon from "discourse/helpers/d-icon";
import {
  addExtraUserClasses,
  renderAvatar,
} from "discourse/helpers/user-avatar";
import { applyValueTransformer } from "discourse/lib/transformer";
import { i18n } from "discourse-i18n";
import UserTip from "../../user-tip";
import UserStatusBubble from "./user-status-bubble";

const DEFAULT_AVATAR_SIZE = "medium";

export default class Notifications extends Component {
  @service currentUser;
  @service siteSettings;

  get avatar() {
    const avatarAttrs = addExtraUserClasses(this.currentUser, {});
    return htmlSafe(
      renderAvatar(this.currentUser, {
        imageSize: this.avatarSize,
        title: i18n("user.avatar.header_title"),
        template: this.currentUser.avatar_template,
        username: this.currentUser.username,
        name: this.siteSettings.enable_names && this.currentUser.name,
        ...avatarAttrs,
      })
    );
  }

  get avatarSize() {
    return applyValueTransformer(
      "header-notifications-avatar-size",
      DEFAULT_AVATAR_SIZE
    );
  }

  get _shouldHighlightAvatar() {
    return (
      !this.currentUser.read_first_notification &&
      !this.currentUser.enforcedSecondFactor &&
      !this.args.active
    );
  }

  get isInDoNotDisturb() {
    return this.currentUser.isInDoNotDisturb();
  }

  <template>
    <PluginOutlet @name="user-dropdown-notifications__before" />
    {{this.avatar}}

    {{#if this._shouldHighlightAvatar}}
      <UserTip
        @id="first_notification"
        @triggerSelector=".header-dropdown-toggle.current-user"
        @placement="bottom-end"
        @titleText={{i18n "user_tips.first_notification.title"}}
        @contentText={{i18n "user_tips.first_notification.content"}}
        @showSkipButton={{true}}
        @priority={{1000}}
      />
    {{/if}}

    {{#if this.currentUser.status}}
      <UserStatusBubble
        @timezone={{this.this.currentUser.user_option.timezone}}
        @status={{this.currentUser.status}}
      />
    {{/if}}

    {{#if this.isInDoNotDisturb}}
      <div
        class="do-not-disturb-background"
        title={{i18n "notifications.paused"}}
      >{{icon "discourse-dnd"}}</div>
    {{else}}
      {{#if this.currentUser.new_personal_messages_notifications_count}}
        <a
          href="#"
          class="badge-notification with-icon new-pms"
          title={{i18n
            "notifications.tooltip.new_message_notification"
            (hash
              count=this.currentUser.new_personal_messages_notifications_count
            )
          }}
          aria-label={{i18n
            "notifications.tooltip.new_message_notification"
            (hash
              count=this.currentUser.new_personal_messages_notifications_count
            )
          }}
        >
          {{icon "envelope"}}
        </a>
      {{else if this.currentUser.unseen_reviewable_count}}
        <a
          href="#"
          class="badge-notification with-icon new-reviewables"
          title={{i18n
            "notifications.tooltip.new_reviewable"
            (hash count=this.currentUser.unseen_reviewable_count)
          }}
          aria-label={{i18n
            "notifications.tooltip.new_reviewable"
            (hash count=this.currentUser.unseen_reviewable_count)
          }}
        >
          {{icon "flag"}}
        </a>
      {{else if this.currentUser.all_unread_notifications_count}}
        <a
          href="#"
          class="badge-notification unread-notifications"
          title={{i18n
            "notifications.tooltip.regular"
            (hash count=this.currentUser.all_unread_notifications_count)
          }}
          aria-label={{i18n
            "user.notifications"
            (hash count=this.currentUser.all_unread_notifications_count)
          }}
        >
          {{this.currentUser.all_unread_notifications_count}}
        </a>
      {{/if}}
    {{/if}}
    <PluginOutlet @name="user-dropdown-notifications__after" />
  </template>
}
