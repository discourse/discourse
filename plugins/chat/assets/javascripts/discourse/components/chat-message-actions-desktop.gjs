import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import BookmarkIcon from "discourse/components/bookmark-icon";
import DropdownSelectBox from "discourse/select-kit/components/dropdown-select-box";
import { and } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import ChatMessageReaction from "discourse/plugins/chat/discourse/components/chat-message-reaction";
import ChatMessageInteractor from "discourse/plugins/chat/discourse/lib/chat-message-interactor";

const FULL = "full";
const REDUCED = "reduced";
const REDUCED_WIDTH_THRESHOLD = 500;

export default class ChatMessageActionsDesktop extends Component {
  @service site;

  @tracked size = FULL;

  // eslint-disable-next-line no-unused-vars -- `size` is taken to re-run the modifier, not read
  rovingToolbar = modifier((element, [size]) => {
    const items = () =>
      [...element.children]
        .map((child) =>
          child.matches("button, summary")
            ? child
            : child.querySelector("button, summary")
        )
        .filter((item) => item && !item.disabled);

    const setTabStop = (target) => {
      const all = items();
      const stop = all.includes(target) ? target : all[0];
      all.forEach((item) =>
        item.setAttribute("tabindex", item === stop ? "0" : "-1")
      );
    };

    const onKeyDown = (event) => {
      const all = items();
      const index = all.indexOf(document.activeElement);

      if (index === -1) {
        return;
      }

      let target;
      switch (event.key) {
        case "ArrowRight":
          target = all[(index + 1) % all.length];
          break;
        case "ArrowLeft":
          target = all[(index - 1 + all.length) % all.length];
          break;
        case "Home":
          target = all[0];
          break;
        case "End":
          target = all[all.length - 1];
          break;
        default:
          return;
      }

      event.preventDefault();
      setTabStop(target);
      target.focus();
    };

    // Re-asserted on focus: these controls re-render on their own schedule and restore
    // the tabindex they were rendered with.
    const onFocusIn = (event) => {
      if (items().includes(event.target)) {
        setTabStop(event.target);
      }
    };

    // Re-runs on a size change, which swaps the toolbar's items. Keeping the tab stop on
    // whatever holds focus stops a resize from putting a keyboard user back to the start.
    setTabStop(
      element.contains(document.activeElement) ? document.activeElement : null
    );
    element.addEventListener("keydown", onKeyDown);
    element.addEventListener("focusin", onFocusIn);

    return () => {
      element.removeEventListener("keydown", onKeyDown);
      element.removeEventListener("focusin", onFocusIn);
    };
  });

  get message() {
    return this.args.message;
  }

  get context() {
    return this.args.context;
  }

  @cached
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

  // A bookmark's reminder makes a useful name once one is set, but the button needs one
  // before that too — it is icon-only, so its name is all a screen reader has to go on.
  get bookmarkLabel() {
    if (!this.message.bookmark) {
      return i18n("chat.bookmark_message");
    }

    return (
      this.message.bookmark.reminderTitle || i18n("chat.bookmark_message_edit")
    );
  }

  @action
  openEmojiPicker(_, event) {
    event.preventDefault();
    this.messageInteractor.openEmojiPicker(event.target);
  }

  @action
  setSize(element) {
    const boundary = element.closest(".chat-messages-scroller");

    if (boundary) {
      this.size =
        boundary.clientWidth < REDUCED_WIDTH_THRESHOLD ? REDUCED : FULL;
    }
  }

  <template>
    {{#if (and this.site.desktopView @message.persisted)}}
      <div
        class={{dConcatClass
          "chat-message-actions-container"
          (concat "is-size-" this.size)
        }}
        data-id={{this.message.id}}
        {{didInsert this.setSize}}
      >
        <div
          aria-label={{i18n "chat.message_actions"}}
          class={{dConcatClass
            "chat-message-actions"
            (unless
              this.messageInteractor.secondaryActions.length
              "has-no-secondary-actions"
            )
          }}
          role="toolbar"
          {{this.rovingToolbar this.size}}
        >
          {{#if this.shouldRenderFavoriteReactions}}
            {{#each
              this.messageInteractor.emojiReactions key="emoji"
              as |reaction|
            }}
              <ChatMessageReaction
                @disableTooltip={{true}}
                @message={{this.message}}
                @onReaction={{this.messageInteractor.react}}
                @reaction={{reaction}}
                @showCount={{false}}
              />
            {{/each}}
          {{/if}}

          {{#if this.messageInteractor.canInteractWithMessage}}
            <DButton
              class="btn-flat react-btn"
              @action={{this.openEmojiPicker}}
              @forwardEvent={{true}}
              @icon="discourse-emojis"
              @title="chat.react"
            />
          {{/if}}

          {{#if this.messageInteractor.canBookmark}}
            <DButton
              class="btn-flat bookmark-btn"
              @action={{this.messageInteractor.toggleBookmark}}
              @translatedAriaLabel={{this.bookmarkLabel}}
              @translatedTitle={{this.bookmarkLabel}}
            >
              <BookmarkIcon @bookmark={{this.message.bookmark}} />
            </DButton>
          {{/if}}

          {{#if this.messageInteractor.canReply}}
            <DButton
              class="btn-flat reply-btn"
              @action={{this.messageInteractor.reply}}
              @icon="reply"
              @title="chat.reply"
            />
          {{/if}}

          {{#if
            (and
              this.messageInteractor.message
              this.messageInteractor.secondaryActions.length
            )
          }}
            <DropdownSelectBox
              class="more-buttons secondary-actions more-actions-chat"
              @content={{this.messageInteractor.secondaryActions}}
              @onChange={{this.messageInteractor.handleSecondaryActions}}
              @options={{hash
                icon="ellipsis-vertical"
                placement="left"
                customStyle="true"
                btnCustomClasses="btn-flat"
                headerAriaLabel=(i18n "chat.more_message_actions")
              }}
            />
          {{/if}}
        </div>
      </div>
    {{/if}}
  </template>
}
