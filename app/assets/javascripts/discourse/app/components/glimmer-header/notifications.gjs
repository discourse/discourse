import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { addExtraUserClasses } from "discourse/helpers/user-avatar";
import { renderAvatar } from "discourse/helpers/user-avatar";
import { htmlSafe } from "@ember/template";
import icon from "discourse-common/helpers/d-icon";

export default class Notifications extends Component {
  @service userTips;
  @service currentUser;
  @service siteSettings;

  avatarSize = "medium";

  get avatar() {
    let avatarAttrs = {};
    addExtraUserClasses(this.currentUser, avatarAttrs);
    return htmlSafe(
      renderAvatar(this.currentUser, {
        imageSize: this.avatarSize,
        alt: "user.avatar.header_title",
        template: this.currentUser.avatar_template,
        username: this.currentUser.username,
        name: this.siteSettings.enable_names && this.currentUser.name,
        ...avatarAttrs,
      })
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
    {{this.avatar}}

    {{!-- {{#if this._shouldHighlightAvatar}}
        {{this.attach "header-user-tip-shim"}}
      {{/if}} --}}

    {{!-- {{#if this.currentUser.status}}
        {{this.attach "user-status-bubble" this.currentUser.status}}
      {{/if}} --}}

    {{#if this.isInDoNotDisturb}}
      <div class="do-not-disturb-background">{{icon "moon"}}</div>
    {{else}}
      {{#if this.currentUser.new_personal_messages_notifications_count}}
        {{!-- {{this.attach
            "link"
            action=this.attrs.action
            className="badge-notification with-icon new-pms"
            icon="envelope"
            omitSpan=true
            title="notifications.tooltip.new_message_notification"
            titleOptions=(hash
              count=this.currentUser.new_personal_messages_notifications_count
            )
            attributes=(hash
              "aria-label"
              (t
                "notifications.tooltip.new_message_notification"
                (hash
                  count=this.currentUser.new_personal_messages_notifications_count
                )
              )
            )
          }} --}}
      {{else if this.currentUser.unseen_reviewable_count}}
        {{!-- {{this.attach
            "link"
            action=this.attrs.action
            className="badge-notification with-icon new-reviewables"
            icon="flag"
            omitSpan=true
            title="notifications.tooltip.new_reviewable"
            titleOptions=(hash count=this.currentUser.unseen_reviewable_count)
            attributes=(hash
              "aria-label"
              (t
                "notifications.tooltip.new_reviewable"
                (hash count=this.currentUser.unseen_reviewable_count)
              )
            )
          }} --}}
      {{else if this.currentUser.all_unread_notifications_count}}
        {{!-- {{this.attach
            "link"
            action=this.attrs.action
            className="badge-notification unread-notifications"
            rawLabel=this.currentUser.all_unread_notifications_count
            omitSpan=true
            title="notifications.tooltip.regular"
            titleOptions=(hash
              count=this.currentUser.all_unread_notifications_count
            )
            attributes=(hash "aria-label" (t "user.notifications"))
          }} --}}
      {{/if}}
    {{/if}}
  </template>
}
