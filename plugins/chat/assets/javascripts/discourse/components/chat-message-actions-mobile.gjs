import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { and, or } from "truth-helpers";
import BookmarkIcon from "discourse/components/bookmark-icon";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import EmojiPickerDetached from "discourse/components/emoji-picker/detached";
import concatClass from "discourse/helpers/concat-class";
import ChatMessageReaction from "discourse/plugins/chat/discourse/components/chat-message-reaction";
import ChatUserAvatar from "discourse/plugins/chat/discourse/components/chat-user-avatar";
import ChatMessageInteractor from "discourse/plugins/chat/discourse/lib/chat-message-interactor";

export default class ChatMessageActionsMobile extends Component {
  @service chat;
  @service site;
  @service capabilities;
  @service modal;
  @service menu;

  @tracked hasExpandedReply = false;

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

  @action
  vibrate() {
    if (this.capabilities.userHasBeenActive && this.capabilities.canVibrate) {
      navigator.vibrate(5);
    }
  }

  @action
  expandReply(event) {
    event.stopPropagation();
    this.hasExpandedReply = true;
  }

  @action
  collapseMenu(event) {
    event.preventDefault();
    this.args.closeModal();
  }

  @action
  actAndCloseMenu(fnId) {
    this.args.closeModal();
    this.messageInteractor[fnId]();
  }

  @action
  react(name, operation) {
    this.args.closeModal();
    this.messageInteractor.react(name, operation);
  }

  @action
  async openEmojiPicker(_, event) {
    await this.args.closeModal();

    await this.menu.show(event.target, {
      identifier: "emoji-picker",
      groupIdentifier: "emoji-picker",
      component: EmojiPickerDetached,
      modalForMobile: true,
      data: {
        context: "chat",
        didSelectEmoji: this.messageInteractor.selectReaction,
      },
    });
  }

  <template>
    {{#if (and this.site.mobileView this.chat.activeMessage.model.persisted)}}
      <DModal
        @closeModal={{@closeModal}}
        @headerClass="hidden"
        class="chat-message-actions"
        {{didInsert this.vibrate}}
      >
        <:body>
          <div class="selected-message-container">
            <div class="selected-message">
              <ChatUserAvatar @user={{this.message.user}} />
              <span
                {{on "touchstart" this.expandReply passive=true}}
                role="button"
                class={{concatClass
                  "selected-message-reply"
                  (if this.hasExpandedReply "is-expanded")
                }}
              >
                {{this.message.message}}
              </span>
            </div>
          </div>

          <ul class="secondary-actions">
            {{#each this.messageInteractor.secondaryActions as |button|}}
              <li class="chat-message-action-item" data-id={{button.id}}>
                <DButton
                  @translatedLabel={{button.name}}
                  @icon={{button.icon}}
                  @action={{fn this.actAndCloseMenu button.id}}
                  class="chat-message-action"
                />
              </li>
            {{/each}}
          </ul>

          {{#if
            (or this.messageInteractor.canReact this.messageInteractor.canReply)
          }}
            <div class="main-actions">
              {{#if this.messageInteractor.canReact}}
                {{#each this.messageInteractor.emojiReactions as |reaction|}}
                  <ChatMessageReaction
                    @reaction={{reaction}}
                    @onReaction={{this.react}}
                    @message={{this.message}}
                    @showCount={{false}}
                  />
                {{/each}}

                <DButton
                  @icon="discourse-emojis"
                  class="btn-flat react-btn"
                  @action={{this.openEmojiPicker}}
                  @forwardEvent={{true}}
                />
              {{/if}}

              {{#if this.messageInteractor.canBookmark}}
                <DButton
                  @action={{fn this.actAndCloseMenu "toggleBookmark"}}
                  data-id="bookmark"
                  class="btn-flat bookmark-btn"
                >
                  <BookmarkIcon @bookmark={{this.message.bookmark}} />
                </DButton>
              {{/if}}

              {{#if this.messageInteractor.canReply}}
                <DButton
                  @action={{fn this.actAndCloseMenu "reply"}}
                  @icon="reply"
                  @title="chat.reply"
                  data-id="reply"
                  class="chat-message-action reply-btn btn-flat"
                />
              {{/if}}
            </div>
          {{/if}}
        </:body>
      </DModal>
    {{/if}}
  </template>
}
