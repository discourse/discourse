import Component from "@glimmer/component";
import { action } from "@ember/object";
import { emojiUnescape, emojiUrlFor } from "discourse/lib/text";
import I18n from "I18n";
import { schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";
import setupPopover from "discourse/lib/d-popover";

export default class ChatMessageReaction extends Component {
  @service currentUser;

  get showCount() {
    return this.args.showCount ?? true;
  }

  @action
  setupTooltip(element) {
    if (this.args.showTooltip) {
      schedule("afterRender", () => {
        this._tippyInstance?.destroy();
        this._tippyInstance = setupPopover(element, {
          interactive: false,
          allowHTML: true,
          delay: 250,
        });
      });
    }
  }

  @action
  teardownTooltip() {
    this._tippyInstance?.destroy();
  }

  @action
  refreshTooltip() {
    this._tippyInstance?.setContent(this.popoverContent);
  }

  get emojiString() {
    return `:${this.args.reaction.emoji}:`;
  }

  get emojiUrl() {
    return emojiUrlFor(this.args.reaction.emoji);
  }

  @action
  handleClick() {
    this.args.messageActionsHandler.react?.(
      this.args.message,
      this.args.reaction.emoji,
      this.args.reaction.reacted ? "remove" : "add"
    );
    return false;
  }

  get popoverContent() {
    if (!this.args.reaction.count || !this.args.reaction.users?.length) {
      return;
    }

    return emojiUnescape(
      this.args.reaction.reacted
        ? this.#reactionTextWithSelf
        : this.#reactionText
    );
  }

  get #reactionTextWithSelf() {
    const reactionCount = this.args.reaction.count;

    if (reactionCount === 0) {
      return;
    }

    if (reactionCount === 1) {
      return I18n.t("chat.reactions.only_you", {
        emoji: this.args.reaction.emoji,
      });
    }

    const maxUsernames = 5;
    const usernames = this.args.reaction.users
      .filter((user) => user.id !== this.currentUser?.id)
      .slice(0, maxUsernames)
      .mapBy("username");

    if (reactionCount === 2) {
      return I18n.t("chat.reactions.you_and_single_user", {
        emoji: this.args.reaction.emoji,
        username: usernames.pop(),
      });
    }

    const unnamedUserCount = reactionCount - usernames.length;
    if (unnamedUserCount > 0) {
      return I18n.t("chat.reactions.you_multiple_users_and_more", {
        emoji: this.args.reaction.emoji,
        commaSeparatedUsernames: this._joinUsernames(usernames),
        count: unnamedUserCount,
      });
    }

    return I18n.t("chat.reactions.you_and_multiple_users", {
      emoji: this.args.reaction.emoji,
      username: usernames.pop(),
      commaSeparatedUsernames: this._joinUsernames(usernames),
    });
  }

  get #reactionText() {
    const reactionCount = this.args.reaction.count;

    if (reactionCount === 0) {
      return;
    }

    const maxUsernames = 5;
    const usernames = this.args.reaction.users
      .filter((user) => user.id !== this.currentUser?.id)
      .slice(0, maxUsernames)
      .mapBy("username");

    if (reactionCount === 1) {
      return I18n.t("chat.reactions.single_user", {
        emoji: this.args.reaction.emoji,
        username: usernames.pop(),
      });
    }

    const unnamedUserCount = reactionCount - usernames.length;

    if (unnamedUserCount > 0) {
      return I18n.t("chat.reactions.multiple_users_and_more", {
        emoji: this.args.reaction.emoji,
        commaSeparatedUsernames: this._joinUsernames(usernames),
        count: unnamedUserCount,
      });
    }

    return I18n.t("chat.reactions.multiple_users", {
      emoji: this.args.reaction.emoji,
      username: usernames.pop(),
      commaSeparatedUsernames: this._joinUsernames(usernames),
    });
  }

  _joinUsernames(usernames) {
    return usernames.join(I18n.t("word_connector.comma"));
  }
}
