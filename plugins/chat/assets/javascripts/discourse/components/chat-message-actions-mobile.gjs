import Component from "@glimmer/component";
import ChatMessageInteractor from "discourse/plugins/chat/discourse/lib/chat-message-interactor";
import { getOwner } from "@ember/application";
import { tracked } from "@glimmer/tracking";
import discourseLater from "discourse-common/lib/later";
import { action } from "@ember/object";
import { isTesting } from "discourse-common/config/environment";
import { inject as service } from "@ember/service";
import and from "truth-helpers/helpers/and";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import concatClass from "discourse/helpers/concat-class";
import DButton from "discourse/components/d-button";
import { on } from "@ember/modifier";
import ChatUserAvatar from "discourse/plugins/chat/discourse/components/chat/user-avatar";
import ChatMessageReaction from "discourse/plugins/chat/discourse/components/chat-message-reaction";
import { fn } from "@ember/helper";
import or from "truth-helpers/helpers/or";
import BookmarkIcon from "discourse/components/bookmark-icon";

export default class ChatMessageActionsMobile extends Component {
  <template>
    {{! template-lint-disable modifier-name-case }}
    {{#if (and this.site.mobileView this.chat.activeMessage.model.persisted)}}
      <div
        class={{concatClass
          "chat-message-actions-backdrop"
          (if this.showFadeIn "fade-in")
        }}
        {{didInsert this.fadeAndVibrate}}
      >
        <div
          role="button"
          class="collapse-area"
          {{on "touchstart" this.collapseMenu passive=false bubbles=false}}
        >
        </div>

        <div class="chat-message-actions">
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
                    @onReaction={{this.messageInteractor.react}}
                    @message={{this.message}}
                    @showCount={{false}}
                  />
                {{/each}}

                <DButton
                  @action={{this.openEmojiPicker}}
                  @icon="discourse-emojis"
                  @title="chat.react"
                  @forwardEvent={{true}}
                  data-id="react"
                  class="btn-flat react-btn"
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
        </div>
      </div>
    {{/if}}
  </template>

  @service chat;
  @service site;
  @service capabilities;

  @tracked hasExpandedReply = false;
  @tracked showFadeIn = false;

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
  fadeAndVibrate() {
    discourseLater(this.#addFadeIn.bind(this));

    if (this.capabilities.canVibrate && !isTesting()) {
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
    this.#onCloseMenu();
  }

  @action
  actAndCloseMenu(fnId) {
    this.messageInteractor[fnId]();
    this.#onCloseMenu();
  }

  @action
  openEmojiPicker(_, event) {
    this.messageInteractor.openEmojiPicker(_, event);
    this.#onCloseMenu();
  }

  #onCloseMenu() {
    this.#removeFadeIn();

    // we don't want to remove the component right away as it's animating
    // 200 is equal to the duration of the css animation
    discourseLater(() => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      // by ensuring we are not hovering any message anymore
      // we also ensure the menu is fully removed
      this.chat.activeMessage = null;
    }, 200);
  }

  #addFadeIn() {
    this.showFadeIn = true;
  }

  #removeFadeIn() {
    this.showFadeIn = false;
  }
}
