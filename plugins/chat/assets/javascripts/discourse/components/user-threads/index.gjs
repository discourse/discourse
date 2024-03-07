import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { service } from "@ember/service";
import i18n from "discourse-common/helpers/i18n";
import { bind } from "discourse-common/utils/decorators";
import ChannelTitle from "discourse/plugins/chat/discourse/components/channel-title";
import List from "discourse/plugins/chat/discourse/components/chat/list";
import ThreadIndicator from "discourse/plugins/chat/discourse/components/chat-message-thread-indicator";
import ThreadTitle from "discourse/plugins/chat/discourse/components/thread-title";

export default class UserThreads extends Component {
  @service chat;
  @service chatApi;
  @service chatChannelsManager;

  @cached
  get threadsCollection() {
    return this.chatApi.userThreads(this.handleLoadedThreads);
  }

  @bind
  handleLoadedThreads(result) {
    return result.threads.map((threadObject) => {
      const channel = this.chatChannelsManager.store(threadObject.channel);
      const thread = channel.threadsManager.add(channel, threadObject);
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
        <div class="c-user-thread" data-id={{thread.id}}>
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
      <list.EmptyState>
        <div class="empty-state-threads">
          {{i18n "chat.empty_state.my_threads"}}
        </div>
      </list.EmptyState>
    </List>
  </template>
}
