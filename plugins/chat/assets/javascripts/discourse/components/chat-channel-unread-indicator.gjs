import Component from "@glimmer/component";
import { service } from "@ember/service";
import concatClass from "discourse/helpers/concat-class";
import { hasChatIndicator } from "../lib/chat-user-preferences";

export default class ChatChannelUnreadIndicator extends Component {
  @service chat;
  @service site;
  @service currentUser;

  get showUnreadIndicator() {
    return (
      this.args.channel.tracking.unreadCount > 0 ||
      this.args.channel.unreadThreadsCount > 0
    );
  }

  get urgentCount() {
    if (this.#hasChannelMentions()) {
      return this.args.channel.tracking.mentionCount;
    }
    if (this.#hasWatchedThreads()) {
      return this.args.channel.tracking.watchedThreadsUnreadCount;
    }
    return this.args.channel.tracking.unreadCount;
  }

  get isUrgent() {
    if (this.#onlyMentions()) {
      return this.#hasChannelMentions();
    }
    return (
      this.#isDirectMessage() ||
      this.#hasChannelMentions() ||
      this.#hasWatchedThreads()
    );
  }

  #isDirectMessage() {
    return (
      this.args.channel.isDirectMessageChannel &&
      this.args.channel.tracking.unreadCount > 0
    );
  }

  #hasChannelMentions() {
    return this.args.channel.tracking.mentionCount > 0;
  }

  #hasWatchedThreads() {
    return this.args.channel.tracking.watchedThreadsUnreadCount > 0;
  }

  #onlyMentions() {
    return hasChatIndicator(this.currentUser).ONLY_MENTIONS;
  }

  <template>
    {{#if this.showUnreadIndicator}}
      <div
        class={{concatClass
          "chat-channel-unread-indicator"
          (if this.isUrgent "-urgent")
        }}
      >
        <div class="chat-channel-unread-indicator__number">{{#if
            this.isUrgent
          }}{{this.urgentCount}}{{else}}&nbsp;{{/if}}</div>
      </div>
    {{/if}}
  </template>
}
