import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { gt } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";
import formatDate from "discourse/helpers/format-date";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { i18n } from "discourse-i18n";
import ThreadUnreadIndicator from "discourse/plugins/chat/discourse/components/thread-unread-indicator";
import ChatThreadParticipants from "../../chat-thread-participants";
import ChatUserAvatar from "../../chat-user-avatar";

export default class ChatThreadListItem extends Component {
  @service router;

  @action
  openThread(thread) {
    this.router.transitionTo("chat.channel.thread", ...thread.routeModels);
  }

  <template>
    <div
      class={{concatClass
        "chat-thread-list-item"
        (if (gt @thread.tracking.unreadCount 0) "-is-unread")
        (if (gt @thread.tracking.watchedThreadsUnreadCount 0) "-is-urgent")
      }}
      data-thread-id={{@thread.id}}
      ...attributes
    >
      <div class="chat-thread-list-item__main">
        <div
          title={{i18n "chat.thread.view_thread"}}
          role="button"
          class="chat-thread-list-item__open-button"
          {{on "click" (fn this.openThread @thread) passive=true}}
        >
          <div class="chat-thread-list-item__header">
            <div class="chat-thread-list-item__title">
              {{#if @thread.title}}
                {{replaceEmoji @thread.title}}
              {{else}}
                {{replaceEmoji @thread.originalMessage.excerpt}}
              {{/if}}
            </div>
            <div class="chat-thread-list-item__unread-indicator">
              <ThreadUnreadIndicator @thread={{@thread}} />
            </div>
          </div>

          <div class="chat-thread-list-item__metadata">
            <div class="chat-thread-list-item__members">
              <ChatUserAvatar
                @user={{@thread.originalMessage.user}}
                @showPresence={{false}}
                @interactive={{false}}
              />
              <ChatThreadParticipants
                @thread={{@thread}}
                @includeOriginalMessageUser={{false}}
                class="chat-thread-list-item__participants"
              />
            </div>

            <div class="chat-thread-list-item__last-reply-timestamp">
              {{#if @thread.preview.lastReplyCreatedAt}}
                {{formatDate
                  @thread.preview.lastReplyCreatedAt
                  leaveAgo="true"
                }}
              {{/if}}
            </div>
          </div>
        </div>
      </div>
    </div>
  </template>
}
