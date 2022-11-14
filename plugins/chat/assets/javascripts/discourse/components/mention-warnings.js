import Component from "@ember/component";
import { ajax } from "discourse/lib/ajax";
import { computed } from "@ember/object";
import I18n from "I18n";
import { escapeExpression } from "discourse/lib/utilities";
import { htmlSafe } from "@ember/template";
import { bind } from "discourse-common/utils/decorators";

const MENTION_RESULT = {
  unreachable: 0,
  over_members_limit: 1,
  ignored: 2,
};

export default class MentionWarnings extends Component {
  tagName = "";
  mentions = null;
  unreachable = null;
  overMembersLimit = null;
  // Complimentary structure to avoid repeating mention checks.
  warningsSeen = null;
  tooManyMentions = false;

  init() {
    super.init(...arguments);

    this.set("unreachable", []);
    this.set("overMembersLimit", []);
    this.set("warningsSeen", {});
  }

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

    const mentionsCount = this.mentions?.length;

    if (mentionsCount > 0) {
      if (mentionsCount > this.siteSettings.max_mentions_per_chat_message) {
        this.set("tooManyMentions", true);
      } else {
        this.set("tooManyMentions", false);
        const newMentions = this.mentions.filter(
          (mention) => !(mention in this.warningsSeen)
        );

        if (newMentions?.length > 0) {
          this._recordNewWarnings(newMentions);
        } else {
          this._rebuildWarnings();
        }
      }
    } else {
      this.set("tooManyMentions", false);
      this.set("unreachable", []);
      this.set("overMembersLimit", []);
    }
  }

  _recordNewWarnings(newMentions) {
    ajax("/chat/api/mentions/groups.json", {
      data: { mentions: newMentions },
    })
      .then((newWarnings) => {
        newWarnings.unreachable.forEach((warning) => {
          this.warningsSeen[warning] = MENTION_RESULT["unreachable"];
        });

        newWarnings.over_members_limit.forEach((warning) => {
          this.warningsSeen[warning] = MENTION_RESULT["over_members_limit"];
        });

        newWarnings.ignored.forEach((warning) => {
          this.warningsSeen[warning] = MENTION_RESULT["ignored"];
        });

        this._rebuildWarnings();
      })
      .catch(this._rebuildWarnings);
  }

  @bind
  _rebuildWarnings() {
    const newWarnings = this.mentions.reduce(
      (memo, mention) => {
        if (
          mention in this.warningsSeen &&
          !(this.warningsSeen[mention] === MENTION_RESULT["ignored"])
        ) {
          if (this.warningsSeen[mention] === MENTION_RESULT["unreachable"]) {
            memo[0].push(mention);
          } else {
            memo[1].push(mention);
          }
        }

        return memo;
      },
      [[], []]
    );

    this.set("unreachable", newWarnings[0]);
    this.set("overMembersLimit", newWarnings[1]);
  }

  @computed("unreachable", "overMembersLimit", "tooManyMentions")
  get show() {
    return (
      this.tooManyMentions ||
      this.unreachable.length > 0 ||
      this.overMembersLimit.length > 0
    );
  }

  @computed("unreachable", "overMembersLimit", "tooManyMentions")
  get listStyleClass() {
    if (this.tooManyMentions) {
      return "chat-mention-warnings-list-simple";
    }

    if (this.unreachable.length + this.overMembersLimit.length > 1) {
      return "chat-mention-warnings-list-multiple";
    } else {
      return "chat-mention-warnings-list-simple";
    }
  }

  @computed("unreachable", "overMembersLimit", "mentions", "tooManyMentions")
  get warningHeaderText() {
    const errorsCount = this.unreachable.length + this.overMembersLimit.length;
    if (this.mentions.length < errorsCount || this.tooManyMentions) {
      return I18n.t("chat.mention_warning.groups.header.all");
    } else {
      return I18n.t("chat.mention_warning.groups.header.some");
    }
  }

  @computed("tooManyMentions")
  get tooManyMentionsBody() {
    if (!this.tooManyMentions) {
      return;
    }

    let notificationLimit;
    if (this.currentUser.staff) {
      const limitText = escapeExpression(
        I18n.t("chat.mention_warning.notification_limit")
      );
      notificationLimit = htmlSafe(
        `<a 
          target="_blank" 
          href="/admin/site_settings/category/plugins?filter=max_mentions_per_chat_message"
        >
          ${limitText}
        </a>`
      );
    }

    return htmlSafe(
      I18n.t("chat.mention_warning.too_many_mentions", {
        notification_limit: notificationLimit,
        limit: this.siteSettings.max_mentions_per_chat_message,
      })
    );
  }

  @computed("unreachable")
  get unnreachableBody() {
    if (this.unreachable.length === 0) {
      return;
    }

    if (this.unreachable.length <= 2) {
      return I18n.t("chat.mention_warning.groups.unreachable", {
        group: this.unreachable[0],
        group_2: this.unreachable[1],
        count: this.unreachable.length,
      });
    } else {
      return I18n.t("chat.mention_warning.groups.unreachable_multiple", {
        group: this.unreachable[0],
        count: this.unreachable.length - 1, //N others
      });
    }
  }

  @computed("overMembersLimit")
  get overMembersLimitBody() {
    if (this.overMembersLimit.length === 0) {
      return;
    }

    let notificationLimit;
    if (this.currentUser.staff) {
      const limitText = escapeExpression(
        I18n.t("chat.mention_warning.notification_limit")
      );
      notificationLimit = htmlSafe(
        `<a 
          target="_blank" 
          href="/admin/site_settings/category/plugins?filter=max_users_notified_per_group_mention"
        >
          ${limitText}
        </a>`
      );
    }

    if (this.overMembersLimit.length <= 2) {
      return htmlSafe(
        I18n.t("chat.mention_warning.groups.too_many_members", {
          group: this.overMembersLimit[0],
          group_2: this.overMembersLimit[1],
          count: this.overMembersLimit.length,
          notification_limit: notificationLimit,
          limit: this.siteSettings.max_mentions_per_chat_message,
        })
      );
    } else {
      return htmlSafe(
        I18n.t("chat.mention_warning.groups.too_many_members_multiple", {
          group: this.overMembersLimit[0],
          count: this.overMembersLimit.length - 1, //N others
          notification_limit: notificationLimit,
          limit: this.siteSettings.max_mentions_per_chat_message,
        })
      );
    }
  }
}
