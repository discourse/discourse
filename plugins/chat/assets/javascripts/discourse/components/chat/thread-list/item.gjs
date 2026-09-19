import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { gt } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
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
      class={{dConcatClass
        "chat-thread-list-item"
        (if (gt @thread.tracking.unreadCount 0) "-is-unread")
        (if (gt @thread.tracking.watchedThreadsUnreadCount 0) "-is-urgent")
      }}
      data-thread-id={{@thread.id}}
      ...attributes
    >
      <div class="chat-thread-list-item__main">
        <div
          class="chat-thread-list-item__open-button"
          role="button"
          title={{i18n "chat.thread.view_thread"}}
          {{on "click" (fn this.openThread @thread) passive=true}}
        >
          <div class="chat-thread-list-item__header">
            <div class="chat-thread-list-item__title">
              {{#if @thread.title}}
                {{dReplaceEmoji @thread.title}}
              {{else}}
                {{dReplaceEmoji @thread.originalMessage.excerpt}}
              {{/if}}
            </div>
            <div class="chat-thread-list-item__unread-indicator">
              <ThreadUnreadIndicator @thread={{@thread}} />
            </div>
          </div>

          <div class="chat-thread-list-item__metadata">
            <div class="chat-thread-list-item__members">
              <ChatUserAvatar
                @interactive={{false}}
                @showPresence={{false}}
                @user={{@thread.originalMessage.user}}
              />
              <ChatThreadParticipants
                class="chat-thread-list-item__participants"
                @includeOriginalMessageUser={{false}}
                @thread={{@thread}}
              />
            </div>

            <div class="chat-thread-list-item__last-reply-timestamp">
              {{#if @thread.preview.lastReplyCreatedAt}}
                {{dFormatDate
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
