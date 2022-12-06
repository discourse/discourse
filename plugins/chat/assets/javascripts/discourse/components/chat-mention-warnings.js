import Component from "@glimmer/component";
import I18n from "I18n";
import { htmlSafe } from "@ember/template";
import { inject as service } from "@ember/service";

export default class ChatMentionWarnings extends Component {
  @service siteSettings;
  @service currentUser;

  get unreachableGroupMentionsCount() {
    return this.args?.unreachableGroupMentions.length;
  }

  get overMembersLimitMentionsCount() {
    return this.args?.overMembersLimitGroupMentions.length;
  }

  get hasTooManyMentions() {
    return this.args?.tooManyMentions;
  }

  get hasUnreachableGroupMentions() {
    return this.unreachableGroupMentionsCount > 0;
  }

  get hasOverMembersLimitGroupMentions() {
    return this.overMembersLimitMentionsCount > 0;
  }

  get warningsCount() {
    return (
      this.unreachableGroupMentionsCount + this.overMembersLimitMentionsCount
    );
  }

  get show() {
    return (
      this.hasTooManyMentions ||
      this.hasUnreachableGroupMentions ||
      this.hasOverMembersLimitGroupMentions
    );
  }

  get listStyleClass() {
    if (this.hasTooManyMentions) {
      return "chat-mention-warnings-list__simple";
    }

    if (this.warningsCount > 1) {
      return "chat-mention-warnings-list__multiple";
    } else {
      return "chat-mention-warnings-list__simple";
    }
  }

  get warningHeaderText() {
    if (
      this.args?.mentionsCount <= this.warningsCount ||
      this.hasTooManyMentions
    ) {
      return I18n.t("chat.mention_warning.groups.header.all");
    } else {
      return I18n.t("chat.mention_warning.groups.header.some");
    }
  }

  get tooManyMentionsBody() {
    if (!this.hasTooManyMentions) {
      return;
    }

    let notificationLimit = I18n.t(
      "chat.mention_warning.groups.notification_limit"
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
    if (!this.hasUnreachableGroupMentions) {
      return;
    }

    if (this.unreachableGroupMentionsCount <= 2) {
      return I18n.t("chat.mention_warning.groups.unreachable", {
        group: this.args.unreachableGroupMentions[0],
        group_2: this.args.unreachableGroupMentions[1],
        count: this.unreachableGroupMentionsCount,
      });
    } else {
      return I18n.t("chat.mention_warning.groups.unreachable_multiple", {
        group: this.args.unreachableGroupMentions[0],
        count: this.unreachableGroupMentionsCount - 1, //N others
      });
    }
  }

  get overMembersLimitBody() {
    if (!this.hasOverMembersLimitGroupMentions) {
      return;
    }

    let notificationLimit = I18n.t(
      "chat.mention_warning.groups.notification_limit"
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

    if (this.hasOverMembersLimitGroupMentions <= 2) {
      return htmlSafe(
        I18n.t("chat.mention_warning.groups.too_many_members", {
          group: this.args.overMembersLimitGroupMentions[0],
          group_2: this.args.overMembersLimitGroupMentions[1],
          count: this.overMembersLimitMentionsCount,
          notification_limit: notificationLimit,
          limit: settingLimit,
        })
      );
    } else {
      return htmlSafe(
        I18n.t("chat.mention_warning.groups.too_many_members_multiple", {
          group: this.args.overMembersLimitGroupMentions[0],
          count: this.overMembersLimitMentionsCount - 1, //N others
          notification_limit: notificationLimit,
          limit: settingLimit,
        })
      );
    }
  }
}
