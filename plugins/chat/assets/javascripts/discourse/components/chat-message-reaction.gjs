import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import { bind } from "discourse/lib/decorators";
import discourseLater from "discourse/lib/later";
import { emojiUnescape, emojiUrlFor } from "discourse/lib/text";
import { and, eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import ChatMessageReactionsUsers from "discourse/plugins/chat/discourse/components/chat-message-reactions-users";
import { getReactionText } from "discourse/plugins/chat/discourse/lib/get-reaction-text";

let descriptionSequence = 0;

export default class ChatMessageReaction extends Component {
  @service currentUser;
  @service menu;
  @service site;
  @service siteSettings;
  @service tooltip;

  registerTooltip = modifier((element) => {
    if (
      this.args.disableTooltip ||
      this.useReactionsUsersPopup ||
      !this.popoverContent?.length
    ) {
      return;
    }

    const instance = this.tooltip.register(element, {
      content: this.description,
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

  // With the new reactions popup enabled, hovering (desktop) or long-pressing
  // (mobile) a reaction opens a users popup centred on that reaction. Each
  // reaction registers its own popup; the shared `groupIdentifier` ensures only
  // one is open at a time, so moving to another reaction opens a fresh popup.
  registerReactionsUsersPopup = modifier((element) => {
    if (!this.useReactionsUsersPopup) {
      return;
    }

    const desktop = !this.site.mobileView;

    const instance = this.menu.register(element, {
      identifier: "chat-message-reaction-users",
      groupIdentifier: "chat-message-reaction-users",
      component: ChatMessageReactionsUsers,
      modalForMobile: true,
      arrow: true,
      offset: 15,
      placement: "bottom",
      fallbackPlacements: ["top"],
      triggers: desktop ? ["hover"] : ["hold"],
      data: {
        message: this.args.message,
        emoji: this.args.reaction.emoji,
        // Lets the popup keep itself open while the pointer is over it, so the
        // hover-to-open popup only closes once the pointer leaves both the
        // reaction and the popup.
        onContentPointerEnter: desktop
          ? this.cancelCloseReactionsUsersPopup
          : undefined,
        onContentPointerLeave: desktop
          ? this.scheduleCloseReactionsUsersPopup
          : undefined,
      },
    });
    this.#reactionsUsersPopupInstance = instance;

    if (desktop) {
      element.addEventListener(
        "pointerenter",
        this.cancelCloseReactionsUsersPopup,
        { passive: true }
      );
      element.addEventListener(
        "pointerleave",
        this.scheduleCloseReactionsUsersPopup,
        { passive: true }
      );
      element.addEventListener("focus", this.openReactionsUsersPopup, {
        passive: true,
      });
      element.addEventListener("blur", this.scheduleCloseReactionsUsersPopup, {
        passive: true,
      });
    }

    return () => {
      cancel(this.#closeReactionsUsersPopupTimer);
      element.removeEventListener(
        "pointerenter",
        this.cancelCloseReactionsUsersPopup
      );
      element.removeEventListener(
        "pointerleave",
        this.scheduleCloseReactionsUsersPopup
      );
      element.removeEventListener("focus", this.openReactionsUsersPopup);
      element.removeEventListener(
        "blur",
        this.scheduleCloseReactionsUsersPopup
      );
      instance.destroy();
      this.#reactionsUsersPopupInstance = null;
    };
  });

  descriptionId = `chat-message-reaction-description-${descriptionSequence++}`;
  #reactionsUsersPopupInstance = null;
  #closeReactionsUsersPopupTimer = null;

  // Close on a short delay so moving the pointer across the gap between the
  // reaction and the popup (or briefly off either) doesn't dismiss it.
  @bind
  scheduleCloseReactionsUsersPopup() {
    cancel(this.#closeReactionsUsersPopupTimer);
    this.#closeReactionsUsersPopupTimer = discourseLater(() => {
      this.#reactionsUsersPopupInstance?.close({ focusTrigger: false });
    }, 250);
  }

  @bind
  openReactionsUsersPopup() {
    this.cancelCloseReactionsUsersPopup();
    this.#reactionsUsersPopupInstance?.show();
  }

  @bind
  cancelCloseReactionsUsersPopup() {
    cancel(this.#closeReactionsUsersPopupTimer);
  }

  // When the new reactions popup is enabled the reaction opens a users popup, so
  // the names tooltip is suppressed here.
  get useReactionsUsersPopup() {
    return (
      this.siteSettings.enable_new_chat_reactions_popup &&
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

    if (!this.currentUser) {
      getOwner(this).lookup("route:application").send("showLogin");
      return;
    }

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

  get description() {
    return this.popoverContent ? trustHTML(this.popoverContent) : undefined;
  }

  <template>
    {{#if (and @reaction this.emojiUrl)}}
      <button
        {{on "click" this.handleClick passive=true}}
        {{this.registerTooltip}}
        {{this.registerReactionsUsersPopup}}
        type="button"
        title={{this.emojiString}}
        data-emoji-name={{@reaction.emoji}}
        {{! `interactive` is opt-out, as it is on the message itself: only an explicit
        false makes a reaction display-only. }}
        tabindex={{if (eq @interactive false) "-1" "0"}}
        aria-pressed={{if @reaction.reacted "true" "false"}}
        aria-describedby={{if this.description this.descriptionId}}
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

      {{#if this.description}}
        <span
          id={{this.descriptionId}}
          class="sr-only"
        >{{this.description}}</span>
      {{/if}}
    {{/if}}
  </template>
}
