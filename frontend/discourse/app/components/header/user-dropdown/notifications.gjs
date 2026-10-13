import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import { applyValueTransformer } from "discourse/lib/transformer";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import {
  addExtraUserClasses,
  renderAvatar,
} from "discourse/ui-kit/helpers/d-user-avatar";
import { i18n } from "discourse-i18n";
import UserTip from "../../user-tip";
import UserStatusBubble from "./user-status-bubble";

const DEFAULT_AVATAR_SIZE = "medium";

export default class Notifications extends Component {
  @service currentUser;
  @service siteSettings;

  get avatar() {
    const avatarAttrs = addExtraUserClasses(this.currentUser, {});
    return trustHTML(
      renderAvatar(this.currentUser, {
        imageSize: this.avatarSize,
        hideTitle: true,
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
        @contentText={{i18n "user_tips.first_notification.content"}}
        @id="first_notification"
        @placement="bottom-end"
        @portalOutletSelector=".d-header-wrap"
        @priority={{1000}}
        @showSkipButton={{true}}
        @titleText={{i18n "user_tips.first_notification.title"}}
        @triggerSelector=".header-dropdown-toggle.current-user"
      />
    {{/if}}

    {{#if this.currentUser.status}}
      <UserStatusBubble
        @status={{this.currentUser.status}}
        @timezone={{this.currentUser.user_option.timezone}}
      />
    {{/if}}

    {{#if this.isInDoNotDisturb}}
      <div
        class="do-not-disturb-background"
        title={{i18n "notifications.paused"}}
      >{{dIcon "discourse-dnd"}}</div>
    {{else}}
      {{#if this.currentUser.new_personal_messages_notifications_count}}
        <a
          aria-label={{i18n
            "notifications.tooltip.new_message_notification"
            (hash
              count=this.currentUser.new_personal_messages_notifications_count
            )
          }}
          class="badge-notification with-icon new-pms"
          href="#"
          title={{i18n
            "notifications.tooltip.new_message_notification"
            (hash
              count=this.currentUser.new_personal_messages_notifications_count
            )
          }}
        >
          {{dIcon "envelope"}}
        </a>
      {{else if this.currentUser.unseen_reviewable_count}}
        <a
          aria-label={{i18n
            "notifications.tooltip.new_reviewable"
            (hash count=this.currentUser.unseen_reviewable_count)
          }}
          class="badge-notification with-icon new-reviewables"
          href="#"
          title={{i18n
            "notifications.tooltip.new_reviewable"
            (hash count=this.currentUser.unseen_reviewable_count)
          }}
        >
          {{dIcon "flag"}}
        </a>
      {{else if this.currentUser.all_unread_notifications_count}}
        <a
          aria-label={{i18n
            "user.notifications"
            (hash count=this.currentUser.all_unread_notifications_count)
          }}
          class="badge-notification unread-notifications"
          href="#"
          title={{i18n
            "notifications.tooltip.regular"
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
