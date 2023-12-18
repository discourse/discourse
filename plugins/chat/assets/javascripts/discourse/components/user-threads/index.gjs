import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { bind } from "discourse-common/utils/decorators";
import ChannelTitle from "discourse/plugins/chat/discourse/components/channel-title";
import List from "discourse/plugins/chat/discourse/components/chat/list";
import ThreadIndicator from "discourse/plugins/chat/discourse/components/chat-message-thread-indicator";
import ThreadTitle from "discourse/plugins/chat/discourse/components/thread-title";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";
import ChatThread from "discourse/plugins/chat/discourse/models/chat-thread";

export default class UserThreads extends Component {
  @service chat;
  @service chatApi;

  @cached
  get threadsCollection() {
    return this.chatApi.userThreads(this.handleLoadedThreads);
  }

  @bind
  handleLoadedThreads(result) {
    return result.threads.map((threadObject) => {
      const channel = ChatChannel.create(threadObject.channel);
      const thread = ChatThread.create(channel, threadObject);
      const tracking = result.tracking[thread.id];
      if (tracking) {
        thread.tracking.mentionCount = tracking.mention_count;
        thread.tracking.unreadCount = tracking.unread_count;
      }
      return thread;
    });
  }

  <template>
    <List
      @collection={{this.threadsCollection}}
      class="c-user-threads"
      as |list|
    >
      <list.Item as |thread|>
        <div class="c-user-thread">
          <ThreadTitle @thread={{thread}} />
          <ChannelTitle @channel={{thread.channel}} />
          <ThreadIndicator
            @message={{thread.originalMessage}}
            @interactiveUser={{false}}
            @interactiveThread={{false}}
            tabindex="-1"
          />
        </div>
      </list.Item>
    </List>
  </template>
}
