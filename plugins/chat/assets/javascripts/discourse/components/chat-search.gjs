import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { isPresent } from "@ember/utils";
import AsyncContent from "discourse/components/async-content";
import FilterInput from "discourse/components/filter-input";
import { ajax } from "discourse/lib/ajax";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import { INPUT_DELAY } from "discourse/lib/environment";
import getURL from "discourse/lib/get-url";
import DiscourseURL from "discourse/lib/url";
import autoFocus from "discourse/modifiers/auto-focus";
import tabToSibling from "discourse/modifiers/tab-to-sibling";
import { i18n } from "discourse-i18n";
import ChatChannelTitle from "discourse/plugins/chat/discourse/components/chat-channel-title";
import ChatMessageComponent from "discourse/plugins/chat/discourse/components/chat-message";
import ChatThreadHeading from "discourse/plugins/chat/discourse/components/chat-thread-heading";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";

export default class ChatSearch extends Component {
  @service router;

  query = this.args.query;

  /**
   * Removes mentions from query text for highlighting purposes
   * @param {string} query - The search query string
   * @returns {string} - Query with mentions removed
   */
  cleanQueryForHighlighting(query) {
    if (!query) {
      return "";
    }

    // Remove mentions (@username) from the query
    // This handles cases like "@bas foo", "bar @bas foo", "foo @bas"
    return query
      .replace(/@\w+/g, "") // Remove @mentions
      .replace(/\s+/g, " ") // Replace multiple spaces with single space
      .trim(); // Remove leading/trailing whitespace
  }

  @bind
  async searchMessages() {
    const response = await ajax("/chat/api/search", {
      data: { query: this.args.query, channel_id: this.args.scopedChannelId },
    });

    if (!response.messages?.length) {
      return;
    }

    return response.messages.map((messageObject) => {
      return ChatMessage.create(
        ChatChannel.create(messageObject.channel),
        messageObject
      );
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
  debounceFilterChange(query) {
    this.router.replaceWith({ queryParams: { q: query } });
  }

  @action
  loadExistingQuery() {
    if (isPresent(this.args.query)) {
      this.debounceFilterChange(this.args.query);
    }
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

  @action
  handleKeypress(message, event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      this.visitMessage(message);
    }
  }

  /**
   * Generate accessible label for a chat message search result
   * @param {Object} message - The chat message object
   * @returns {string} - Screen reader friendly description
   */
  accessibleMessageLabel(message) {
    const username = message.user?.username || i18n("chat.deleted_user");
    const messagePreview =
      message.excerpt ||
      (message.message ? message.message.substring(0, 100) + "..." : "");
    const threadInfo = message.threadTitle
      ? i18n("chat.search_view.in_thread", { title: message.threadTitle })
      : "";

    return i18n("chat.search_view.message_result_label", {
      username,
      preview: messagePreview,
      threadInfo,
    }).trim();
  }

  <template>
    <div class="c-search" {{didInsert this.loadExistingQuery}}>
      <FilterInput
        {{autoFocus}}
        @filterAction={{this.onFilterChange}}
        @value={{@query}}
        @icons={{hash right="magnifying-glass"}}
        placeholder={{i18n "chat.search_view.filter_placeholder"}}
        class="no-blur"
      />

      <AsyncContent @asyncData={{this.searchMessages}}>
        <:empty>
          {{#if @query.length}}
            <div class="alert alert-info">
              {{i18n "chat.search_view.no_results"}}
            </div>
          {{/if}}
        </:empty>

        <:content as |messages|>
          <div id="chat-search-instructions" class="sr-only">
            {{i18n "chat.search_view.sr_instructions"}}
          </div>

          <ul
            class="chat-message-search-entries"
            role="listbox"
            aria-label={{i18n "chat.search_view.results_list_label"}}
          >
            {{#each messages as |message|}}
              <li
                class="chat-message-search-entry"
                role="option"
                {{on "click" (fn this.visitMessage message)}}
                {{on "keydown" (fn this.handleKeypress message)}}
                {{tabToSibling}}
                tabindex="0"
                aria-label={{this.accessibleMessageLabel message}}
                aria-describedby="chat-search-instructions"
              >

                <div class="chat-message-search-entry__info">
                  {{#unless @scopedChannelId}}
                    <ChatChannelTitle @channel={{message.channel}} />
                  {{/unless}}

                  <ChatThreadHeading
                    @thread={{hash title=message.threadTitle}}
                  />
                </div>

                <ChatMessageComponent
                  @message={{message}}
                  @disableMouseEvents={{true}}
                  @includeSeparator={{false}}
                  @highlightedText={{this.cleanQueryForHighlighting @query}}
                  @interactive={{false}}
                />
              </li>
            {{/each}}
          </ul>
        </:content>
      </AsyncContent>
    </div>
  </template>
}
