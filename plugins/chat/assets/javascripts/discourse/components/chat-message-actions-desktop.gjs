import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import ChatMessageInteractor from "discourse/plugins/chat/discourse/lib/chat-message-interactor";
import { getOwner } from "@ember/application";
import { schedule } from "@ember/runloop";
import { createPopper } from "@popperjs/core";
import chatMessageContainer from "discourse/plugins/chat/discourse/lib/chat-message-container";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import concatClass from "discourse/helpers/concat-class";
import BookmarkIcon from "discourse/components/bookmark-icon";
import ChatMessageReaction from "discourse/plugins/chat/discourse/components/chat-message-reaction";
import DButton from "discourse/components/d-button";
import DropdownSelectBox from "select-kit/components/dropdown-select-box";
import { on } from "@ember/modifier";
import and from "truth-helpers/helpers/and";
import { concat, hash } from "@ember/helper";

const MSG_ACTIONS_VERTICAL_PADDING = -10;
const FULL = "full";
const REDUCED = "reduced";
const REDUCED_WIDTH_THRESHOLD = 500;

export default class ChatMessageActionsDesktop extends Component {
  <template>
    {{! template-lint-disable modifier-name-case }}
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
            {{#each
              this.messageInteractor.emojiReactions key="emoji"
              as |reaction|
            }}
              <ChatMessageReaction
                @reaction={{reaction}}
                @onReaction={{this.messageInteractor.react}}
                @message={{this.message}}
                @showCount={{false}}
              />
            {{/each}}
          {{/if}}

          {{#if this.messageInteractor.canInteractWithMessage}}
            <DButton
              @action={{this.messageInteractor.openEmojiPicker}}
              @icon="discourse-emojis"
              @title="chat.react"
              @forwardEvent={{true}}
              class="btn-flat react-btn"
            />
          {{/if}}

          {{#if this.messageInteractor.canBookmark}}
            <DButton
              @action={{this.messageInteractor.toggleBookmark}}
              class="btn-flat bookmark-btn"
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
              @class="more-buttons secondary-actions"
              @options={{hash
                icon="ellipsis-v"
                placement="left"
                customStyle="true"
                btnCustomClasses="btn-flat"
              }}
              @content={{this.messageInteractor.secondaryActions}}
              @onChange={{this.messageInteractor.handleSecondaryActions}}
            />
          {{/if}}
        </div>
      </div>
    {{/if}}
  </template>

  @service chat;
  @service chatEmojiPickerManager;
  @service site;

  @tracked size = FULL;

  popper = null;

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

  @action
  onWheel() {
    // prevents menu to stop scroll on the list of messages
    this.chat.activeMessage = null;
  }

  @action
  setup(element) {
    this.popper?.destroy();

    schedule("afterRender", () => {
      const messageContainer = chatMessageContainer(
        this.message.id,
        this.context
      );

      if (!messageContainer) {
        return;
      }

      const viewport = messageContainer.closest(".popper-viewport");
      this.size =
        viewport.clientWidth < REDUCED_WIDTH_THRESHOLD ? REDUCED : FULL;

      if (!messageContainer) {
        return;
      }

      this.popper = createPopper(messageContainer, element, {
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
}
