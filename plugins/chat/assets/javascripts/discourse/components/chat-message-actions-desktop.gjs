import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { createPopper } from "@popperjs/core";
import { and } from "truth-helpers";
import BookmarkIcon from "discourse/components/bookmark-icon";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import DropdownSelectBox from "select-kit/components/dropdown-select-box";
import ChatMessageReaction from "discourse/plugins/chat/discourse/components/chat-message-reaction";
import chatMessageContainer from "discourse/plugins/chat/discourse/lib/chat-message-container";
import ChatMessageInteractor from "discourse/plugins/chat/discourse/lib/chat-message-interactor";
import ChatMessageReactionModel from "discourse/plugins/chat/discourse/models/chat-message-reaction";

const MSG_ACTIONS_VERTICAL_PADDING = -10;
const FULL = "full";
const REDUCED = "reduced";
const REDUCED_WIDTH_THRESHOLD = 500;

export default class ChatMessageActionsDesktop extends Component {
  @service chat;
  @service site;
  @service emojiStore;

  @tracked size = FULL;

  popper = null;

  get favoriteReactions() {
    return this.emojiStore
      .favoritesForContext(`channel_${this.message.channel.id}`)
      .slice(0, 3)
      .map(
        (emoji) =>
          this.message.reactions.find((reaction) => reaction.emoji === emoji) ||
          ChatMessageReactionModel.create({ emoji })
      );
  }

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
    return this.size === FULL;
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
  onWheel() {
    // prevents menu to stop scroll on the list of messages
    this.chat.activeMessage = null;
  }

  @action
  setup(element) {
    this.popper?.destroy();

    schedule("afterRender", () => {
      if (!this.messageContainer) {
        return;
      }

      const viewport = this.messageContainer.closest(".popper-viewport");
      this.size =
        viewport.clientWidth < REDUCED_WIDTH_THRESHOLD ? REDUCED : FULL;

      if (!this.messageContainer) {
        return;
      }

      this.popper = createPopper(this.messageContainer, element, {
        placement: "top-end",
        strategy: "fixed",
        modifiers: [
          {
            name: "flip",
            enabled: true,
            options: {
              boundary: viewport,
              fallbackPlacements: ["bottom-end"],
            },
          },
          { name: "hide", enabled: true },
          { name: "eventListeners", options: { scroll: false } },
          {
            name: "offset",
            options: { offset: [-2, MSG_ACTIONS_VERTICAL_PADDING] },
          },
        ],
      });
    });
  }

  @action
  teardown() {
    this.popper?.destroy();
    this.popper = null;
  }

  <template>
    {{#if (and this.site.desktopView this.chat.activeMessage.model.persisted)}}
      <div
        {{didInsert this.setup}}
        {{didUpdate this.setup this.chat.activeMessage.model.id}}
        {{on "wheel" this.onWheel passive=true}}
        {{willDestroy this.teardown}}
        class={{concatClass
          "chat-message-actions-container"
          (concat "is-size-" this.size)
        }}
        data-id={{this.message.id}}
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
            {{#each this.favoriteReactions as |reaction|}}
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
              class="more-buttons secondary-actions"
            />
          {{/if}}
        </div>
      </div>
    {{/if}}
  </template>
}
