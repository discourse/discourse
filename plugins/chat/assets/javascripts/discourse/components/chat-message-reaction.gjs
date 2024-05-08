import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import { and } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";
import { emojiUnescape, emojiUrlFor } from "discourse/lib/text";
import { getReactionText } from "discourse/plugins/chat/discourse/lib/get-reaction-text";

export default class ChatMessageReaction extends Component {
  @service capabilities;
  @service currentUser;
  @service tooltip;
  @service site;

  @tracked isActive = false;

  registerTooltip = modifier((element) => {
    if (this.disableTooltip || !this.popoverContent?.length) {
      return;
    }

    const instance = this.tooltip.register(element, {
      content: htmlSafe(this.popoverContent),
      identifier: "chat-message-reaction-tooltip",
      animated: false,
      placement: "top",
      fallbackPlacements: ["bottom"],
      triggers: this.site.mobileView ? ["hold"] : ["hover"],
    });

    return () => {
      instance?.destroy();
    };
  });

  get disableTooltip() {
    return this.args.disableTooltip ?? false;
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
        type="button"
        tabindex="0"
        class={{concatClass
          "chat-message-reaction"
          (if @reaction.reacted "reacted")
          (if this.isActive "-active")
        }}
        data-emoji-name={{@reaction.emoji}}
        title={{this.emojiString}}
        {{on "click" this.handleClick passive=true}}
        {{this.registerTooltip}}
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
