import Component from "@glimmer/component";
import { action } from "@ember/object";
import I18n from "I18n";
import { tracked } from "@glimmer/tracking";
import discourseLater from "discourse-common/lib/later";
import { ajax } from "discourse/lib/ajax";
import { cancel } from "@ember/runloop";

export default class PostSendMentionWarnings extends Component {
  @tracked invitesSent = false;
  @tracked invitesSentCount = 0;

  willDestroy() {
    cancel(this._invitationSentTimer);
  }

  get warnings() {
    return this.args.warnings;
  }

  get show() {
    return this.warnings?.length > 0 || this.invitesSent;
  }

  get translatedWarnings() {
    return this.warnings.map((warning) => {
      warning.translation = I18n.t(`chat.mention_warning.${warning.type}`, {
        mention: warning.mentions[0],
        count: warning.mentions.length,
        others: this._othersTranslation(warning.mentions.length - 1),
      });

      if (warning.type === "without_membership") {
        warning.include_invite_link = true;
      }

      return warning;
    });
  }

  _othersTranslation(othersCount) {
    return I18n.t("chat.mention_warning.warning_multiple", {
      count: othersCount,
    });
  }

  @action
  dismiss() {
    this.args.dismiss();
  }

  @action
  inviteMentioned(warning) {
    ajax(`/chat/${this.args.chatChannelId}/invite`, {
      method: "PUT",
      data: {
        user_ids: warning.mention_target_ids,
        chat_message_id: this.args.messageId,
      },
    }).then(() => {
      this.invitesSent = true;
      this.invitesSentCount = warning.mention_target_ids.length;

      this._invitationSentTimer = discourseLater(() => {
        this.dismiss();
        this.invitesSentCount = 0;
        this.invitesSent = false;
      }, 3000);
    });

    return false;
  }
}
