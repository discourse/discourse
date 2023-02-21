import { guidFor } from "@ember/object/internals";
import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { emojiUnescape, emojiUrlFor } from "discourse/lib/text";
import setupPopover from "discourse/lib/d-popover";
import I18n from "I18n";
import { schedule } from "@ember/runloop";

export default class ChatMessageReaction extends Component {
  reaction = null;
  showUsersList = false;
  tagName = "";
  message = null;
  messageActionsHandler = null;
  class = null;

  didReceiveAttrs() {
    this._super(...arguments);

    if (this.showUsersList) {
      schedule("afterRender", () => {
        this._popover?.destroy();
        this._popover = this._setupPopover();
      });
    }
  }

  willDestroyElement() {
    this._super(...arguments);

    this._popover?.destroy();
  }

  @computed
  get componentId() {
    return guidFor(this);
  }

  @computed("reaction.emoji")
  get emojiString() {
    return `:${this.reaction.emoji}:`;
  }

  @computed("reaction.emoji")
  get emojiUrl() {
    return emojiUrlFor(this.reaction.emoji);
  }

  @action
  handleClick() {
    this?.messageActionsHandler.react(
      this.message,
      this.reaction.emoji,
      this.reaction.reacted ? "remove" : "add"
    );
    return false;
  }

  _setupPopover() {
    const target = document.getElementById(this.componentId);

    if (!target) {
      return;
    }

    const popover = setupPopover(target, {
      interactive: false,
      allowHTML: true,
      delay: 250,
      content: emojiUnescape(this.popoverContent),
      onClickOutside(instance) {
        instance.hide();
      },
      onTrigger(instance, event) {
        // ensures we close other reactions popovers when triggering one
        document
          .querySelectorAll(".chat-message-reaction")
          .forEach((chatMessageReaction) => {
            chatMessageReaction?._tippy?.hide();
          });

        event.stopPropagation();
      },
    });

    return popover?.id ? popover : null;
  }

  @computed("reaction")
  get popoverContent() {
    return this.reaction.reacted
      ? this._reactionTextWithSelf()
      : this._reactionText();
  }

  _reactionTextWithSelf() {
    const reactionCount = this.reaction.count;

    if (reactionCount === 0) {
      return;
    }

    if (reactionCount === 1) {
      return I18n.t("chat.reactions.only_you", {
        emoji: this.reaction.emoji,
      });
    }

    const maxUsernames = 4;
    const usernames = this.reaction.users
      .slice(0, maxUsernames)
      .mapBy("username");

    if (reactionCount === 2) {
      return I18n.t("chat.reactions.you_and_single_user", {
        emoji: this.reaction.emoji,
        username: usernames.pop(),
      });
    }

    // `-1` because the current user ("you") isn't included in `usernames`
    const unnamedUserCount = reactionCount - usernames.length - 1;

    if (unnamedUserCount > 0) {
      return I18n.t("chat.reactions.you_multiple_users_and_more", {
        emoji: this.reaction.emoji,
        commaSeparatedUsernames: this._joinUsernames(usernames),
        count: unnamedUserCount,
      });
    }

    return I18n.t("chat.reactions.you_and_multiple_users", {
      emoji: this.reaction.emoji,
      username: usernames.pop(),
      commaSeparatedUsernames: this._joinUsernames(usernames),
    });
  }

  _reactionText() {
    const reactionCount = this.reaction.count;

    if (reactionCount === 0) {
      return;
    }

    const maxUsernames = 5;
    const usernames = this.reaction.users
      .slice(0, maxUsernames)
      .mapBy("username");

    if (reactionCount === 1) {
      return I18n.t("chat.reactions.single_user", {
        emoji: this.reaction.emoji,
        username: usernames.pop(),
      });
    }

    const unnamedUserCount = reactionCount - usernames.length;

    if (unnamedUserCount > 0) {
      return I18n.t("chat.reactions.multiple_users_and_more", {
        emoji: this.reaction.emoji,
        commaSeparatedUsernames: this._joinUsernames(usernames),
        count: unnamedUserCount,
      });
    }

    return I18n.t("chat.reactions.multiple_users", {
      emoji: this.reaction.emoji,
      username: usernames.pop(),
      commaSeparatedUsernames: this._joinUsernames(usernames),
    });
  }

  _joinUsernames(usernames) {
    return usernames.join(I18n.t("word_connector.comma"));
  }
}
