import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import {
  computePosition,
  flip,
  hide,
  limitShift,
  offset,
  shift,
} from "@floating-ui/dom";
import BookmarkIcon from "discourse/components/bookmark-icon";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import DropdownSelectBox from "discourse/select-kit/components/dropdown-select-box";
import { and } from "discourse/truth-helpers";
import ChatMessageReaction from "discourse/plugins/chat/discourse/components/chat-message-reaction";
import chatMessageContainer from "discourse/plugins/chat/discourse/lib/chat-message-container";
import ChatMessageInteractor from "discourse/plugins/chat/discourse/lib/chat-message-interactor";

const MSG_ACTIONS_VERTICAL_PADDING = -10;
const FULL = "full";
const REDUCED = "reduced";
const REDUCED_WIDTH_THRESHOLD = 500;

export default class ChatMessageActionsDesktop extends Component {
  @service chat;
  @service site;

  @tracked size = FULL;

  get message() {
    return this.chat.activeMessage.model;
  }

  get context() {
    return this.chat.activeMessage.context;
  }

  get messageInteractor() {
    return new ChatMessageInteractor(
      getOwner(this),
      this.message,
      this.context
    );
  }

  get shouldRenderFavoriteReactions() {
    return this.size === FULL && this.message.channel?.isFollowing;
  }

  get messageContainer() {
    return chatMessageContainer(this.message.id, this.context);
  }

  @action
  openEmojiPicker(_, event) {
    event.preventDefault();
    this.messageInteractor.openEmojiPicker(event.target);
  }

  @action
  setup(element) {
    if (!this.messageContainer) {
      return;
    }

    const boundary = this.messageContainer.closest(".chat-messages-scroller");
    this.size = boundary.clientWidth < REDUCED_WIDTH_THRESHOLD ? REDUCED : FULL;

    computePosition(this.messageContainer, element, {
      placement: "top-end",
      strategy: "fixed",
      middleware: [
        offset({
          mainAxis: MSG_ACTIONS_VERTICAL_PADDING,
          crossAxis: -2,
        }),
        flip({
          boundary,
          fallbackPlacements: ["bottom-end"],
        }),
        shift({ limiter: limitShift() }),
        hide({ strategy: "referenceHidden" }),
        hide({ strategy: "escaped" }),
      ],
    }).then(({ x, y, middlewareData }) => {
      const style = {
        left: `${x}px`,
        top: `${y}px`,
      };

      if (
        middlewareData.hide?.referenceHidden ||
        middlewareData.hide?.escaped
      ) {
        style.visibility = "hidden";
        style.pointerEvents = "none";
      } else {
        style.visibility = "visible";
        style.pointerEvents = "auto";
      }

      Object.assign(element.style, style);
    });
  }

  @action
  redirectScroll(event) {
    event.preventDefault();

    const targetElement = this.messageContainer.closest(
      ".chat-messages-scroller"
    );

    if (!targetElement) {
      return;
    }

    targetElement.scrollTop += event.deltaY;
  }

  <template>
    {{#if (and this.site.desktopView this.chat.activeMessage.model.persisted)}}
      <div
        {{didInsert this.setup}}
        {{didUpdate this.setup this.chat.activeMessage.model.id}}
        class={{concatClass
          "chat-message-actions-container"
          (concat "is-size-" this.size)
        }}
        data-id={{this.message.id}}
        {{on "wheel" this.redirectScroll}}
      >
        <div
          class={{concatClass
            "chat-message-actions"
            (unless
              this.messageInteractor.secondaryActions.length
              "has-no-secondary-actions"
            )
          }}
        >
          {{#if this.shouldRenderFavoriteReactions}}
            {{#each this.messageInteractor.emojiReactions as |reaction|}}
              <ChatMessageReaction
                @reaction={{reaction}}
                @onReaction={{this.messageInteractor.react}}
                @message={{this.message}}
                @showCount={{false}}
                @disableTooltip={{true}}
              />
            {{/each}}
          {{/if}}

          {{#if this.messageInteractor.canInteractWithMessage}}
            <DButton
              @action={{this.openEmojiPicker}}
              @forwardEvent={{true}}
              @icon="discourse-emojis"
              class="btn-flat react-btn"
            />
          {{/if}}

          {{#if this.messageInteractor.canBookmark}}
            <DButton
              @action={{this.messageInteractor.toggleBookmark}}
              class="btn-flat bookmark-btn"
              @translatedTitle={{this.message.bookmark.reminderTitle}}
            >
              <BookmarkIcon @bookmark={{this.message.bookmark}} />
            </DButton>
          {{/if}}

          {{#if this.messageInteractor.canReply}}
            <DButton
              @action={{this.messageInteractor.reply}}
              @icon="reply"
              @title="chat.reply"
              class="btn-flat reply-btn"
            />
          {{/if}}

          {{#if
            (and
              this.messageInteractor.message
              this.messageInteractor.secondaryActions.length
            )
          }}
            <DropdownSelectBox
              @options={{hash
                icon="ellipsis-vertical"
                placement="left"
                customStyle="true"
                btnCustomClasses="btn-flat"
              }}
              @content={{this.messageInteractor.secondaryActions}}
              @onChange={{this.messageInteractor.handleSecondaryActions}}
              class="more-buttons secondary-actions more-actions-chat"
            />
          {{/if}}
        </div>
      </div>
    {{/if}}
  </template>
}
