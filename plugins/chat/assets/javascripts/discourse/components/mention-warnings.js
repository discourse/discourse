import Component from "@glimmer/component";
import I18n from "I18n";
import { escapeExpression } from "discourse/lib/utilities";
import { htmlSafe } from "@ember/template";
import { inject as service } from "@ember/service";

export default class MentionWarnings extends Component {
  @service siteSettings;
  @service currentUser;
  tagName = "";

  get show() {
    return (
      this.args.tooManyMentions ||
      this.args.unreachableGroupMentions.length > 0 ||
      this.args.overMembersLimitGroupMentions.length > 0
    );
  }

  get listStyleClass() {
    if (this.args.tooManyMentions) {
      return "chat-mention-warnings-list-simple";
    }

    if (
      this.args.unreachableGroupMentions.length +
        this.args.overMembersLimitGroupMentions.length >
      1
    ) {
      return "chat-mention-warnings-list-multiple";
    } else {
      return "chat-mention-warnings-list-simple";
    }
  }

  get warningHeaderText() {
    const errorsCount =
      this.args.unreachableGroupMentions.length +
      this.args.overMembersLimitGroupMentions.length;
    if (this.args.mentionsCount <= errorsCount || this.args.tooManyMentions) {
      return I18n.t("chat.mention_warning.groups.header.all");
    } else {
      return I18n.t("chat.mention_warning.groups.header.some");
    }
  }

  get tooManyMentionsBody() {
    if (!this.args.tooManyMentions) {
      return;
    }

    let notificationLimit = escapeExpression(
      I18n.t("chat.mention_warning.groups.notification_limit")
    );

    if (this.currentUser.staff) {
      notificationLimit = htmlSafe(
        `<a 
          target="_blank" 
          href="/admin/site_settings/category/plugins?filter=max_mentions_per_chat_message"
        >
          ${notificationLimit}
        </a>`
      );
    }

    const settingLimit = I18n.t("chat.mention_warning.mentions_limit", {
      count: this.siteSettings.max_mentions_per_chat_message,
    });

    return htmlSafe(
      I18n.t("chat.mention_warning.too_many_mentions", {
        notification_limit: notificationLimit,
        limit: settingLimit,
      })
    );
  }

  get unreachableBody() {
    if (this.args.unreachableGroupMentions.length === 0) {
      return;
    }

    if (this.args.unreachableGroupMentions.length <= 2) {
      return I18n.t("chat.mention_warning.groups.unreachable", {
        group: this.args.unreachableGroupMentions[0],
        group_2: this.args.unreachableGroupMentions[1],
        count: this.args.unreachableGroupMentions.length,
      });
    } else {
      return I18n.t("chat.mention_warning.groups.unreachable_multiple", {
        group: this.args.unreachableGroupMentions[0],
        count: this.args.unreachableGroupMentions.length - 1, //N others
      });
    }
  }

  get overMembersLimitBody() {
    if (this.args.overMembersLimitGroupMentions.length === 0) {
      return;
    }

    let notificationLimit = escapeExpression(
      I18n.t("chat.mention_warning.groups.notification_limit")
    );
    if (this.currentUser.staff) {
      notificationLimit = htmlSafe(
        `<a 
          target="_blank" 
          href="/admin/site_settings/category/plugins?filter=max_users_notified_per_group_mention"
        >
          ${notificationLimit}
        </a>`
      );
    }

    const settingLimit = I18n.t("chat.mention_warning.groups.users_limit", {
      count: this.siteSettings.max_users_notified_per_group_mention,
    });

    if (this.args.overMembersLimitGroupMentions.length <= 2) {
      return htmlSafe(
        I18n.t("chat.mention_warning.groups.too_many_members", {
          group: this.args.overMembersLimitGroupMentions[0],
          group_2: this.args.overMembersLimitGroupMentions[1],
          count: this.args.overMembersLimitGroupMentions.length,
          notification_limit: notificationLimit,
          limit: settingLimit,
        })
      );
    } else {
      return htmlSafe(
        I18n.t("chat.mention_warning.groups.too_many_members_multiple", {
          group: this.args.overMembersLimitGroupMentions[0],
          count: this.args.overMembersLimitGroupMentions.length - 1, //N others
          notification_limit: notificationLimit,
          limit: settingLimit,
        })
      );
    }
  }
}
