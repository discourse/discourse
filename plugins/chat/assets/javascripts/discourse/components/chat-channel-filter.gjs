import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import { isBlank } from "@ember/utils";
import { gt } from "truth-helpers";
import DButton from "discourse/components/d-button";
import FilterInput from "discourse/components/filter-input";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import autoFocus from "discourse/modifiers/auto-focus";
import { i18n } from "discourse-i18n";

export default class ChatChannelFilter extends Component {
  @service capabilities;
  @service loadingSlider;

  @tracked channelFilterResults;
  @tracked currentChannelFilter = "";
  @tracked currentChannelFilterResult;
  @tracked currentChannelFilterResultIndex = 0;
  @tracked noResults = false;

  get currentFilterResultPosition() {
    return this.currentChannelFilterResultIndex + 1;
  }

  @action
  clearInput() {
    this.currentChannelFilter = "";
  }

  @action
  navigateToPreviousResult() {
    if (!this.channelFilterResults?.length) {
      return;
    }

    const newIndex =
      this.currentChannelFilterResultIndex <
      this.channelFilterResults.length - 1
        ? this.currentChannelFilterResultIndex + 1
        : 0;

    this.currentChannelFilterResultIndex = newIndex;
    this.navigateToResult(this.channelFilterResults[newIndex]);
  }

  @action
  navigateToNextResult() {
    if (!this.channelFilterResults?.length) {
      return;
    }

    const newIndex =
      this.currentChannelFilterResultIndex > 0
        ? this.currentChannelFilterResultIndex - 1
        : this.channelFilterResults.length - 1;

    this.currentChannelFilterResultIndex = newIndex;
    this.navigateToResult(this.channelFilterResults[newIndex]);
  }

  @action
  navigateToResult(result) {
    this.currentChannelFilterResult = result;

    if (this.capabilities.isIOS) {
      document.activeElement.blur(); // prevents a bug on iOS where the body would scroll unexpectedly
    }

    this.args.onLoadTargetMessageId(this.currentChannelFilterResult.id);
  }

  @action
  clearFilteringState() {
    this.noResults = false;
    this.currentChannelFilter = "";
    this.channelFilterResults = null;
    this.currentChannelFilterResult = null;
    this.currentChannelFilterResultIndex = 0;
  }

  @action
  loadSearchResults(event) {
    this.currentChannelFilter = event.target.value;

    if (isBlank(this.currentChannelFilter)) {
      cancel(this, this.performSearch);
      this.searchRequest?.abort?.();
      this.clearFilteringState();
      cancel(this.debouncedSearch);
      return;
    }

    this.debouncedSearch = discourseDebounce(
      this,
      this.performSearch,
      this.currentChannelFilter,
      // given we have to blur on iOS, we give more time to the user
      // to avoid bluring in the middle of a query
      this.capabilities.isIOS ? INPUT_DELAY * 2 : INPUT_DELAY
    );
  }

  async performSearch(query) {
    this.searchRequest?.abort?.();

    try {
      this.noResults = false;
      this.loadingSlider.transitionStarted();

      this.searchRequest = ajax("/chat/api/search", {
        data: {
          query,
          channel_id: this.args.channel.id,
          exclude_threads: true,
          sort: "latest",
        },
      });

      const response = await this.searchRequest;

      this.channelFilterResults = response.messages;
      this.currentChannelFilterResultIndex = 0;

      if (!this.channelFilterResults?.length) {
        this.noResults = true;
        return;
      }

      this.navigateToResult(this.channelFilterResults[0]);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loadingSlider.transitionEnded();
    }
  }

  <template>
    {{#if @isFiltering}}
      <div
        class="chat-channel__filter-bar"
        {{didInsert this.clearFilteringState}}
      >
        <div>
          <FilterInput
            {{autoFocus}}
            @value={{this.currentChannelFilter}}
            placeholder={{i18n "chat.search.title"}}
            @filterAction={{this.loadSearchResults}}
            class="no-blur"
            @onClearInput={{this.clearInput}}
          />

          {{#if this.channelFilterResults.length}}
            <span class="chat-channel__filter-position">
              <span
                class="chat-channel__filter-position-index"
              >{{this.currentFilterResultPosition}}</span>
              <span class="chat-channel__filter-position-separator">/</span>
              <span
                class="chat-channel__filter-position-total"
              >{{this.channelFilterResults.length}}</span>
            </span>

            {{#if (gt this.channelFilterResults.length 1)}}
              <DButton
                @action={{this.navigateToPreviousResult}}
                @icon="chevron-up"
                class="btn-small btn-flat chat-channel__prev-result"
              />
              <DButton
                @action={{this.navigateToNextResult}}
                @icon="chevron-down"
                class="btn-small btn-flat chat-channel__next-result"
              />
            {{/if}}
          {{/if}}

          <DButton
            @action={{fn @onToggleFilter false}}
            class="btn-small btn-flat"
            @label="done"
          />
        </div>

        {{#if this.noResults}}
          <div class="alert alert-info">
            {{i18n "chat.search.no_results"}}
          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
