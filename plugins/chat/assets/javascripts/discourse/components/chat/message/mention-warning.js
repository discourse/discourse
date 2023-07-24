import Component from "@glimmer/component";
import { action } from "@ember/object";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { inject as service } from "@ember/service";
import I18n from "I18n";

export default class ChatMessageMentionWarning extends Component {
  @service("chat-api") api;

  @action
  async onSendInvite() {
    const userIds = this.mentionWarning.withoutMembership.mapBy("id");

    try {
      await this.api.invite(this.args.message.channel.id, userIds, {
        messageId: this.args.message.id,
      });

      this.mentionWarning.invitationSent = true;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  onDismissInvitationSent() {
    this.mentionWarning.invitationSent = false;
  }

  @action
  onDismissMentionWarning() {
    this.args.message.mentionWarning = null;
  }

  get shouldRender() {
    return (
      this.mentionWarning &&
      (this.mentionWarning.groupWithMentionsDisabled?.length ||
        this.mentionWarning.cannotSee?.length ||
        this.mentionWarning.withoutMembership?.length ||
        this.mentionWarning.groupsWithTooManyMembers?.length ||
        this.mentionWarning.globalMentionsDisabled)
    );
  }

  get mentionWarning() {
    return this.args.message.mentionWarning;
  }

  get mentionedCannotSeeText() {
    return this.#findTranslatedWarning(
      "chat.mention_warning.cannot_see",
      "chat.mention_warning.cannot_see_multiple",
      {
        username: this.mentionWarning?.cannotSee?.[0]?.username,
        count: this.mentionWarning?.cannotSee?.length,
      }
    );
  }

  get mentionedWithoutMembershipText() {
    return this.#findTranslatedWarning(
      "chat.mention_warning.without_membership",
      "chat.mention_warning.without_membership_multiple",
      {
        username: this.mentionWarning?.withoutMembership?.[0]?.username,
        count: this.mentionWarning?.withoutMembership?.length,
      }
    );
  }

  get groupsWithDisabledMentions() {
    return this.#findTranslatedWarning(
      "chat.mention_warning.group_mentions_disabled",
      "chat.mention_warning.group_mentions_disabled_multiple",
      {
        group_name: this.mentionWarning?.groupWithMentionsDisabled?.[0],
        count: this.mentionWarning?.groupWithMentionsDisabled?.length,
      }
    );
  }

  get groupsWithTooManyMembers() {
    return this.#findTranslatedWarning(
      "chat.mention_warning.too_many_members",
      "chat.mention_warning.too_many_members_multiple",
      {
        group_name: this.mentionWarning.groupsWithTooManyMembers?.[0],
        count: this.mentionWarning.groupsWithTooManyMembers?.length,
      }
    );
  }

  #findTranslatedWarning(oneKey, multipleKey, args) {
    const translationKey = args.count === 1 ? oneKey : multipleKey;
    args.count--;
    return I18n.t(translationKey, args);
  }
}
