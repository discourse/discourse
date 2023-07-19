import Component from "@glimmer/component";
import { action } from "@ember/object";
import { emojiUnescape, emojiUrlFor } from "discourse/lib/text";
import I18n from "I18n";
import { cancel } from "@ember/runloop";
import { inject as service } from "@ember/service";
import setupPopover from "discourse/lib/d-popover";
import discourseLater from "discourse-common/lib/later";
import { tracked } from "@glimmer/tracking";

export default class ChatMessageReaction extends Component {
  @service capabilities;
  @service currentUser;

  @tracked isActive = false;

  get showCount() {
    return this.args.showCount ?? true;
  }

  @action
  setup(element) {
    this.setupListeners(element);
    this.setupTooltip(element);
  }

  @action
  teardown() {
    cancel(this.longPressHandler);
    this.teardownTooltip();
  }

  @action
  setupListeners(element) {
    this.element = element;

    if (this.capabilities.touch) {
      this.element.addEventListener("touchstart", this.onTouchStart, {
        passive: true,
      });
      this.element.addEventListener("touchmove", this.cancelTouch, {
        passive: true,
      });
      this.element.addEventListener("touchend", this.onTouchEnd);
      this.element.addEventListener("touchCancel", this.cancelTouch);
    }

    this.element.addEventListener("click", this.handleClick, {
      passive: true,
    });
  }

  @action
  teardownListeners() {
    if (this.capabilities.touch) {
      this.element.removeEventListener("touchstart", this.onTouchStart, {
        passive: true,
      });
      this.element.removeEventListener("touchmove", this.cancelTouch, {
        passive: true,
      });
      this.element.removeEventListener("touchend", this.onTouchEnd);
      this.element.removeEventListener("touchCancel", this.cancelTouch);
    }

    this.element.removeEventListener("click", this.handleClick, {
      passive: true,
    });
  }

  @action
  onTouchStart(event) {
    event.stopPropagation();
    this.isActive = true;

    this.longPressHandler = discourseLater(() => {
      this.touching = false;
    }, 400);

    this.touching = true;
  }

  @action
  cancelTouch() {
    cancel(this.longPressHandler);
    this._tippyInstance?.hide();
    this.touching = false;
    this.isActive = false;
  }

  @action
  onTouchEnd(event) {
    event.preventDefault();

    if (this.touching) {
      this.handleClick(event);
    }

    cancel(this.longPressHandler);
    this._tippyInstance?.hide();
    this.isActive = false;
  }

  @action
  setupTooltip(element) {
    this._tippyInstance = setupPopover(element, {
      trigger: "mouseenter",
      interactive: false,
      allowHTML: true,
      offset: [0, 10],
      onShow(instance) {
        if (instance.props.content === "") {
          return false;
        }
      },
    });
  }

  @action
  teardownTooltip() {
    this._tippyInstance?.destroy();
  }

  @action
  refreshTooltip() {
    this._tippyInstance?.setContent(this.popoverContent || "");
  }

  get emojiString() {
    return `:${this.args.reaction.emoji}:`;
  }

  get emojiUrl() {
    return emojiUrlFor(this.args.reaction.emoji);
  }

  @action
  handleClick(event) {
    event.stopPropagation();

    this.args.onReaction?.(
      this.args.reaction.emoji,
      this.args.reaction.reacted ? "remove" : "add"
    );

    this._tippyInstance?.clearDelayTimeouts();
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
        commaSeparatedUsernames: this.#joinUsernames(usernames),
        count: unnamedUserCount,
      });
    }

    return I18n.t("chat.reactions.you_and_multiple_users", {
      emoji: this.args.reaction.emoji,
      username: usernames.pop(),
      commaSeparatedUsernames: this.#joinUsernames(usernames),
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
        commaSeparatedUsernames: this.#joinUsernames(usernames),
        count: unnamedUserCount,
      });
    }

    return I18n.t("chat.reactions.multiple_users", {
      emoji: this.args.reaction.emoji,
      username: usernames.pop(),
      commaSeparatedUsernames: this.#joinUsernames(usernames),
    });
  }

  #joinUsernames(usernames) {
    return usernames.join(I18n.t("word_connector.comma"));
  }
}
