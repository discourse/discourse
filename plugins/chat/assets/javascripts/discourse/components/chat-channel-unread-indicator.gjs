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
      // We want to do this so we don't show a blue dot if the user is inside
      // the channel and a new unread thread comes in.
      (this.args.channel.isCategoryChannel && this.chat.activeChannel?.id !== this.args.channel.id &&
        this.args.channel.unreadThreadsCountSinceLastViewed > 0)
    );
  }

  get unreadCount() {
    let totalUnreads = this.args.channel.tracking.unreadCount;
    if(this.isUrgent) {
      return this.args.channel.tracking.mentionCount + this.args.channel.tracking.watchedThreadsUnreadCount + totalUnreads;
    }

    return totalUnreads;
  }

  get isUrgent() {
    if (this.#onlyMentions()) {
      return this.#hasChannelMentions();
    }
    return (
      this.args.channel.isDirectMessageChannel ||
      this.#hasChannelMentions() ||
      this.#hasWatchedThreads()
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
          }}{{this.unreadCount}}{{else}}&nbsp;{{/if}}</div>
      </div>
    {{/if}}
  </template>
}
