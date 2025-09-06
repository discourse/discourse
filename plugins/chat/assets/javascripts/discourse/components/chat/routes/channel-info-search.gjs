import { on } from "@ember/modifier";
import DiscourseURL from "discourse/lib/url";
import getURL from "discourse/lib/get-url";
import icon from "discourse/helpers/d-icon";
import { INPUT_DELAY } from "discourse/lib/environment";
import autoFocus from "discourse/modifiers/auto-focus";
import Component from "@glimmer/component";
import AsyncContent from "discourse/components/async-content";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";
import ChatMessageComponent from "discourse/plugins/chat/discourse/components/chat-message";
import { tracked } from "@glimmer/tracking";
import FilterInput from "discourse/components/filter-input";
import { action } from "@ember/object";
import { fn, array, hash } from "@ember/helper";
import discourseDebounce from "discourse/lib/debounce";
import ChatThreadHeading from "discourse/plugins/chat/discourse/components/chat-thread-heading";
import { LinkTo } from "@ember/routing";

export default class ChatRouteChannelInfoSearch extends Component {
  @tracked term = "";

  @bind
  async searchMessages() {
    const response = await ajax(
      `/chat/api/channels/${this.args.channel.id}/messages/search`,
      { data: { term: this.term, channel_id: this.args.channel.id } }
    );

    if (!response.messages?.length) {
      return;
    }

    const channel = ChatChannel.create(response.messages[0].channel);
    return response.messages.map((messageObject) => {
      return ChatMessage.create(channel, messageObject);
    });
  }

  @action
  onFilterChange(element) {
    const value = element.target.value;
    this.debouncedHandler = discourseDebounce(
      this.debounceFilterChange,
      value === "" ? null : value,
      INPUT_DELAY
    );
  }

  @action
  debounceFilterChange(term) {
    this.term = term;
  }

  @action
  visitMessage(message) {
    let url;

    if (message.threadId) {
      url = getURL(
        `/chat/c/-/${message.channel.id}/t/${message.threadId}/${message.id}`
      );
    } else {
      url = getURL(`/chat/c/-/${message.channel.id}/${message.id}`);
    }

    DiscourseURL.routeTo(url);
  }

  <template>
    <div class="c-routes --channel-info-search">
      <div class="c-channel-search">
        <FilterInput
          {{autoFocus}}
          @filterAction={{this.onFilterChange}}
          @value={{this.textFilter}}
          @icons={{hash right="magnifying-glass"}}
          placeholder={{i18n "chat.search_view.filter_placeholder"}}
        />

        <AsyncContent @asyncData={{this.searchMessages}}>
          <:empty>
            {{#if this.term.length}}
              <div class="alert alert-info">
                {{i18n "chat.search_view.no_results"}}
              </div>
            {{/if}}
          </:empty>

          <:content as |messages|>
            <div class="chat-message-search-entries">
              {{#each messages as |message|}}
                <div
                  class="chat-message-search-entry"
                  role="button"
                  {{on "click" (fn this.visitMessage message)}}
                  tabindex="0"
                >
                  <ChatThreadHeading
                    @thread={{hash title=message.threadTitle}}
                  />

                  <ChatMessageComponent
                    @message={{message}}
                    @disableMouseEvents={{true}}
                    @includeSeparator={{false}}
                  />
                </div>
              {{/each}}
            </div>
          </:content>
        </AsyncContent>
      </div>
    </div>
  </template>
}
