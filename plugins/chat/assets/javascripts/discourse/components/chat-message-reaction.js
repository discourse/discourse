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
  react = null;
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
    this?.react(this.reaction.emoji, this.reaction.reacted ? "remove" : "add");
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
    let usernames = this.reaction.users.mapBy("username").join(", ");
    if (this.reaction.reacted) {
      if (this.reaction.count === 1) {
        return I18n.t("chat.reactions.only_you", {
          emoji: this.reaction.emoji,
        });
      } else if (this.reaction.count > 1 && this.reaction.count < 6) {
        return I18n.t("chat.reactions.and_others", {
          usernames,
          emoji: this.reaction.emoji,
        });
      } else if (this.reaction.count >= 6) {
        return I18n.t("chat.reactions.you_others_and_more", {
          usernames,
          emoji: this.reaction.emoji,
          more: this.reaction.count - 5,
        });
      }
    } else {
      if (this.reaction.count > 0 && this.reaction.count < 6) {
        return I18n.t("chat.reactions.only_others", {
          usernames,
          emoji: this.reaction.emoji,
        });
      } else if (this.reaction.count >= 6) {
        return I18n.t("chat.reactions.others_and_more", {
          usernames,
          emoji: this.reaction.emoji,
          more: this.reaction.count - 5,
        });
      }
    }
  }
}
