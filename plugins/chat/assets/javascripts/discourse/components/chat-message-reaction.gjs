import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import { emojiUnescape, emojiUrlFor } from "discourse/lib/text";
import { and } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import ChatMessageReactionsUsers from "discourse/plugins/chat/discourse/components/chat-message-reactions-users";
import { getReactionText } from "discourse/plugins/chat/discourse/lib/get-reaction-text";

export default class ChatMessageReaction extends Component {
  @service currentUser;
  @service menu;
  @service site;
  @service siteSettings;
  @service tooltip;

  registerTooltip = modifier((element) => {
    if (
      this.args.disableTooltip ||
      this.useReactionsUsersMenu ||
      !this.popoverContent?.length
    ) {
      return;
    }

    const instance = this.tooltip.register(element, {
      content: trustHTML(this.popoverContent),
      identifier: "chat-message-reaction-tooltip",
      animated: false,
      placement: "top",
      fallbackPlacements: ["bottom"],
      triggers: this.site.mobileView ? ["hold"] : ["hover"],
    });

    return () => {
      instance.destroy();
    };
  });

  // With the new reactions menu enabled, hovering (desktop) or long-pressing
  // (mobile) a reaction opens a users popup centred on that reaction. Each
  // reaction registers its own menu; the shared `groupIdentifier` ensures only
  // one is open at a time, so moving to another reaction opens a fresh menu.
  registerReactionsUsersMenu = modifier((element) => {
    if (!this.useReactionsUsersMenu) {
      return;
    }

    const instance = this.menu.register(element, {
      identifier: "chat-message-reaction-users",
      groupIdentifier: "chat-message-reaction-users",
      component: ChatMessageReactionsUsers,
      modalForMobile: true,
      placement: "bottom",
      fallbackPlacements: ["top"],
      triggers: this.site.mobileView ? ["hold"] : ["hover"],
      data: {
        message: this.args.message,
        emoji: this.args.reaction.emoji,
      },
    });

    return () => {
      instance.destroy();
    };
  });

  // When the new reactions menu is enabled the reaction opens a users popup, so
  // the names tooltip is suppressed here.
  get useReactionsUsersMenu() {
    return (
      this.siteSettings.enable_new_chat_reactions_menu &&
      !this.args.disableTooltip
    );
  }

  get showCount() {
    return this.args.showCount ?? true;
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
  }

  @cached
  get popoverContent() {
    if (!this.args.reaction.count || !this.args.reaction.users?.length) {
      return;
    }

    return emojiUnescape(getReactionText(this.args.reaction, this.currentUser));
  }

  <template>
    {{#if (and @reaction this.emojiUrl)}}
      <button
        {{on "click" this.handleClick passive=true}}
        {{this.registerTooltip}}
        {{this.registerReactionsUsersMenu}}
        type="button"
        title={{this.emojiString}}
        data-emoji-name={{@reaction.emoji}}
        tabindex={{if @interactive "0" "-1"}}
        class={{dConcatClass
          "chat-message-reaction"
          (if @reaction.reacted "reacted")
        }}
      >
        <img
          loading="lazy"
          class="emoji"
          width="20"
          height="20"
          alt={{this.emojiString}}
          src={{this.emojiUrl}}
        />

        {{#if (and this.showCount @reaction.count)}}
          <span class="count">{{@reaction.count}}</span>
        {{/if}}
      </button>
    {{/if}}
  </template>
}
