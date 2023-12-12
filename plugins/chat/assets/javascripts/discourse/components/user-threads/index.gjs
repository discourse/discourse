import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { modifier } from "ember-modifier";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import isElementInViewport from "discourse/lib/is-element-in-viewport";
import { INPUT_DELAY } from "discourse-common/config/environment";
import discourseDebounce from "discourse-common/lib/debounce";
import { bind } from "discourse-common/utils/decorators";
import ChannelTitle from "discourse/plugins/chat/discourse/components/channel-title";
import ThreadIndicator from "discourse/plugins/chat/discourse/components/chat-message-thread-indicator";
import ThreadTitle from "discourse/plugins/chat/discourse/components/thread-title";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";
import ChatThread from "discourse/plugins/chat/discourse/models/chat-thread";

export default class UserThreads extends Component {
  @service chat;
  @service chatApi;
  @service router;

  loadMore = modifier((element) => {
    this.intersectionObserver = new IntersectionObserver(this.loadThreads);
    this.intersectionObserver.observe(element);

    return () => {
      this.intersectionObserver.disconnect();
    };
  });

  fill = modifier((element) => {
    this.resizeObserver = new ResizeObserver(() => {
      if (isElementInViewport(element)) {
        this.loadThreads();
      }
    });

    this.resizeObserver.observe(element);

    return () => {
      this.resizeObserver.disconnect();
    };
  });

  @cached
  get threadsCollection() {
    return this.chatApi.userThreads(this.handleLoadedThreads);
  }

  @action
  loadThreads() {
    discourseDebounce(this, this.debouncedLoadThreads, INPUT_DELAY);
  }

  async debouncedLoadThreads() {
    await this.threadsCollection.load({ limit: 10 });
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
    <div class="chat__user-threads-container">
      <div class="chat__user-threads" {{this.fill}}>
        {{#each this.threadsCollection.items as |thread|}}
          <div
            class="chat__user-threads__thread-container"
            data-id={{thread.id}}
          >
            <div class="chat__user-threads__thread">
              <div class="chat__user-threads__title">
                <ThreadTitle @thread={{thread}} />
                <ChannelTitle @channel={{thread.channel}} />
              </div>

              <div class="chat__user-threads__thread-indicator">
                <ThreadIndicator
                  @message={{thread.originalMessage}}
                  @interactiveUser={{false}}
                  @interactiveThread={{false}}
                  tabindex="-1"
                />
              </div>
            </div>
          </div>
        {{/each}}

        <div {{this.loadMore}}>
          <br />
        </div>

        <ConditionalLoadingSpinner
          @condition={{this.threadsCollection.loading}}
        />
      </div>
    </div>
  </template>
}
