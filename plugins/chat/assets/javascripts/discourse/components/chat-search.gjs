import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { isBlank } from "@ember/utils";
import { not } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import FilterInput from "discourse/components/filter-input";
import LoadMore from "discourse/components/load-more";
import { ajax } from "discourse/lib/ajax";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import { INPUT_DELAY } from "discourse/lib/environment";
import getURL from "discourse/lib/get-url";
import DiscourseURL from "discourse/lib/url";
import autoFocus from "discourse/modifiers/auto-focus";
import tabToSibling from "discourse/modifiers/tab-to-sibling";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";
import ChatChannelTitle from "discourse/plugins/chat/discourse/components/chat-channel-title";
import ChatMessageComponent from "discourse/plugins/chat/discourse/components/chat-message";
import ChatThreadHeading from "discourse/plugins/chat/discourse/components/chat-thread-heading";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";

export default class ChatSearch extends Component {
  @service router;

  @tracked currentSort = "relevance";
  @tracked messages = [];
  @tracked isLoading = false;
  @tracked offset = 0;
  @tracked hasMoreResults = false;
  @tracked lastQuery = null;

  limit = 20;

  @bind
  async searchMessages(resetResults = true) {
    if (isBlank(this.args.query)) {
      this.messages = [];
      this.offset = 0;
      this.hasMoreResults = false;
      return;
    }

    if (this.isLoading) {
      return;
    }

    this.isLoading = true;

    if (resetResults) {
      this.offset = 0;
      this.messages = [];
    }

    try {
      const response = await ajax("/chat/api/search", {
        data: {
          query: this.args.query,
          channel_id: this.args.scopedChannelId,
          sort: this.currentSort,
          offset: this.offset,
          limit: this.limit,
        },
      });

      const newMessages = (response.messages || []).map((messageObject) => {
        return ChatMessage.create(
          ChatChannel.create(messageObject.channel),
          messageObject
        );
      });

      if (resetResults) {
        this.messages = newMessages;
      } else {
        this.messages = [...this.messages, ...newMessages];
      }

      this.offset += newMessages.length;
      this.hasMoreResults = response.meta?.has_more || false;

      return this.messages;
    } finally {
      this.isLoading = false;
    }
  }

  @action
  sortLabel(sort) {
    return i18n(`chat.search.sort.${sort}`);
  }

  @action
  setCurrentSorting(sort, closeMenu) {
    this.currentSort = sort;
    closeMenu();
    this.searchMessages(true);
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
  async loadMore() {
    if (!this.hasMoreResults || this.isLoading) {
      return;
    }

    await this.searchMessages(false);
  }

  @action
  debounceFilterChange(query) {
    this.router.replaceWith({ queryParams: { q: query } });
  }

  @action
  loadExistingQuery() {
    this.checkQueryChange();
  }

  @action
  checkQueryChange() {
    if (this.lastQuery !== this.args.query) {
      this.lastQuery = this.args.query;
      this.searchMessages(true);
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
    <div
      class="c-search"
      {{didInsert this.loadExistingQuery}}
      {{didUpdate this.checkQueryChange @query}}
    >
      <div class="chat-search__filters">
        <FilterInput
          {{autoFocus}}
          @filterAction={{this.onFilterChange}}
          @value={{@query}}
          @icons={{hash left="magnifying-glass"}}
          placeholder={{i18n "chat.search_view.filter_placeholder"}}
          class="no-blur"
        />

        <DMenu
          @identifier="search-sort-options"
          @label={{this.sortLabel this.currentSort}}
          @icon="sort"
        >
          <:content as |menu|>
            <DropdownMenu as |dropdown|>
              <dropdown.item>
                <DButton
                  @translatedLabel={{this.sortLabel "relevance"}}
                  class="btn-transparent"
                  @action={{fn this.setCurrentSorting "relevance" menu.close}}
                />
              </dropdown.item>
              <dropdown.item>
                <DButton
                  @translatedLabel={{this.sortLabel "latest"}}
                  class="btn-transparent"
                  @action={{fn this.setCurrentSorting "latest" menu.close}}
                />
              </dropdown.item>
            </DropdownMenu>
          </:content>
        </DMenu>
      </div>

      {{#if @query.length}}
        {{#if this.messages.length}}
          <div id="chat-search-instructions" class="sr-only">
            {{i18n "chat.search_view.sr_instructions"}}
          </div>

          <ul
            class="chat-message-search-entries"
            role="listbox"
            aria-label={{i18n "chat.search_view.results_list_label"}}
          >
            {{#each this.messages key="id" as |message|}}
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
                  @interactive={{false}}
                />
              </li>
            {{/each}}
          </ul>

          <div class="chat-search-loading">
            <ConditionalLoadingSpinner @condition={{this.isLoading}} />
          </div>

          {{#if this.hasMoreResults}}
            <LoadMore @action={{this.loadMore}} />
          {{/if}}

          <br />
        {{else if (not this.isLoading)}}
          <div class="alert alert-info">
            {{i18n "chat.search.no_results"}}
          </div>
        {{/if}}
      {{/if}}
    </div>
  </template>
}
