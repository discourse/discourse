/* eslint-disable ember/no-tracked-properties-from-args */
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { SEARCH_TYPE_DEFAULT } from "discourse/controllers/full-page-search";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { isValidSearchTerm, translateResults } from "discourse/lib/search";
import { i18n } from "discourse-i18n";

const AI_RESULTS_TOGGLED = "full-page-search:ai-results-toggled";

export default class AiFullPageSearch extends Component {
  @service appEvents;
  @service siteSettings;

  @tracked searching;
  @tracked AiResults = [];
  @tracked showingAiResults = false;
  @tracked sortOrder = this.args.sortOrder;
  @tracked autoEnabledForZeroResults = false;
  @tracked shouldAutoEnableWhenAiReady = false;
  @tracked hasCompletedSearch = false;

  constructor() {
    super(...arguments);
    this.appEvents.on("full-page-search:trigger-search", this, this.onSearch);
    this.appEvents.on(
      "search:search_result_view",
      this,
      this.onSearchResultsLoaded
    );
    this.onSearch();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off("full-page-search:trigger-search", this, this.onSearch);
    this.appEvents.off(
      "search:search_result_view",
      this,
      this.onSearchResultsLoaded
    );
  }

  @action
  onSearch() {
    if (!this.searchEnabled) {
      return;
    }

    this.searching = true;
    this.hasCompletedSearch = false;
    this.autoEnabledForZeroResults = false;
    this.shouldAutoEnableWhenAiReady = false;
    this.resetAiResults();
    return this.performHyDESearch();
  }

  @action
  onSearchResultsLoaded() {
    // enable AI results if we have zero regular results and AI results are ready
    if (
      this.hasZeroRegularResults &&
      !this.showingAiResults &&
      !this.autoEnabledForZeroResults &&
      this.AiResults.length > 0
    ) {
      this.autoEnabledForZeroResults = true;
      this.showingAiResults = true;
      this.args.addSearchResults(this.AiResults, "topic_id");
      this.appEvents.trigger(AI_RESULTS_TOGGLED, {
        enabled: true,
      });
    }
    // AI results not ready yet, auto-enable when ready
    else if (
      this.hasZeroRegularResults &&
      !this.showingAiResults &&
      !this.autoEnabledForZeroResults &&
      this.AiResults.length === 0
    ) {
      this.shouldAutoEnableWhenAiReady = true;
    }
  }

  get disableToggleSwitch() {
    if (
      this.searching ||
      this.AiResults.length === 0 ||
      !this.validSearchOrder
    ) {
      return true;
    }
  }

  get validSearchOrder() {
    return this.sortOrder === 0;
  }

  get hasZeroRegularResults() {
    if (!this.args.model) {
      return false;
    }
    const postsCount = this.args.model.posts?.length || 0;
    const categoriesCount = this.args.model.categories?.length || 0;
    const tagsCount = this.args.model.tags?.length || 0;
    const usersCount = this.args.model.users?.length || 0;
    return postsCount + categoriesCount + tagsCount + usersCount === 0;
  }

  get searchStateText() {
    if (!this.validSearchOrder) {
      return i18n(
        "discourse_ai.embeddings.semantic_search_results.unavailable"
      );
    }

    return i18n("discourse_ai.embeddings.semantic_search_results.toggle");
  }

  get noResults() {
    return (
      this.hasCompletedSearch &&
      !this.searching &&
      this.validSearchOrder &&
      this.AiResults.length === 0
    );
  }

  get tooltipIdentifier() {
    if (!this.validSearchOrder) {
      return "semantic-search-invalid-sort";
    }
    if (!this.hasCompletedSearch && !this.searching) {
      return "semantic-search-not-submitted";
    }
    if (this.noResults) {
      return "semantic-search-no-results";
    }
    if (this.autoEnabledForZeroResults && this.showingAiResults) {
      return "semantic-search-zero-results";
    }
    return null;
  }

  get tooltipContent() {
    if (!this.validSearchOrder) {
      return i18n(
        "discourse_ai.embeddings.semantic_search_tooltips.invalid_sort"
      );
    }
    if (!this.hasCompletedSearch && !this.searching) {
      return i18n(
        "discourse_ai.embeddings.semantic_search_tooltips.not_submitted"
      );
    }
    if (this.noResults) {
      return i18n(
        "discourse_ai.embeddings.semantic_search_tooltips.no_results"
      );
    }
    if (this.autoEnabledForZeroResults && this.showingAiResults) {
      return i18n(
        "discourse_ai.embeddings.semantic_search_results.zero_results_expanded",
        { count: this.AiResults.length }
      );
    }
    return null;
  }

  get searchTerm() {
    return this.args.searchTerm;
  }

  get searchEnabled() {
    return (
      this.args.searchType === SEARCH_TYPE_DEFAULT &&
      isValidSearchTerm(this.searchTerm, this.siteSettings) &&
      this.validSearchOrder
    );
  }

  get searchClass() {
    if (!this.validSearchOrder) {
      return "unavailable";
    } else if (this.searching) {
      return "in-progress";
    } else if (this.noResults) {
      return "no-results";
    }
  }

  @action
  toggleAiResults() {
    this.appEvents.trigger(AI_RESULTS_TOGGLED, {
      enabled: !this.showingAiResults,
    });
    if (this.showingAiResults) {
      this.args.addSearchResults([], "topic_id");
      this.autoEnabledForZeroResults = false;
    } else {
      this.args.addSearchResults(this.AiResults, "topic_id");
    }
    this.showingAiResults = !this.showingAiResults;
  }

  @action
  resetAiResults() {
    this.AiResults = [];
    this.showingAiResults = false;
    this.args.addSearchResults([], "topic_id");
  }

  performHyDESearch() {
    this.resetAiResults();

    ajax("/discourse-ai/embeddings/semantic-search", {
      data: { q: this.searchTerm },
    })
      .then(async (results) => {
        const model = (await translateResults(results)) || {};

        if (model.posts?.length === 0) {
          return;
        }

        model.posts.forEach((post) => {
          post.generatedByAi = true;
        });

        this.AiResults = model.posts;

        if (
          this.shouldAutoEnableWhenAiReady &&
          !this.showingAiResults &&
          !this.autoEnabledForZeroResults &&
          this.AiResults.length > 0
        ) {
          this.autoEnabledForZeroResults = true;
          this.showingAiResults = true;
          this.shouldAutoEnableWhenAiReady = false;
          this.args.addSearchResults(this.AiResults, "topic_id");
          this.appEvents.trigger(AI_RESULTS_TOGGLED, {
            enabled: true,
          });
        }
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.searching = false;
        this.hasCompletedSearch = true;
      });
  }

  @action
  sortChanged() {
    if (this.sortOrder !== this.args.sortOrder) {
      this.sortOrder = this.args.sortOrder;

      if (this.validSearchOrder) {
        this.onSearch();
      } else {
        this.showingAiResults = false;
        this.hasCompletedSearch = false;
        this.resetAiResults();
      }
    }
  }

  <template>
    <div
      {{didUpdate this.sortChanged @sortOrder}}
      class="semantic-search__container search-results"
      role="region"
    >
      <div class="semantic-search__results">
        {{#if this.tooltipIdentifier}}
          <DTooltip @identifier={{this.tooltipIdentifier}}>
            <:trigger>
              <div
                class={{concatClass
                  "semantic-search__searching"
                  this.searchClass
                }}
              >
                <DToggleSwitch
                  disabled={{this.disableToggleSwitch}}
                  @state={{this.showingAiResults}}
                  class="semantic-search__results-toggle"
                  {{on "click" this.toggleAiResults}}
                />
                <div class="semantic-search__searching-text">
                  {{this.searchStateText}}
                  {{#if this.searching}}
                    <div class="spinner small"></div>
                  {{else if this.hasCompletedSearch}}
                    <span
                      class={{concatClass
                        "badge-notification"
                        (if this.AiResults.length "--has-results")
                      }}
                    >{{this.AiResults.length}}</span>
                  {{/if}}
                </div>
              </div>
            </:trigger>
            <:content>{{this.tooltipContent}}</:content>
          </DTooltip>
        {{else}}
          <div
            class={{concatClass "semantic-search__searching" this.searchClass}}
          >
            <DToggleSwitch
              disabled={{this.disableToggleSwitch}}
              @state={{this.showingAiResults}}
              class="semantic-search__results-toggle"
              {{on "click" this.toggleAiResults}}
            />
            <div class="semantic-search__searching-text">
              {{this.searchStateText}}
              {{#if this.searching}}
                <div class="spinner small"></div>
              {{else if this.hasCompletedSearch}}
                <span
                  class={{concatClass
                    "badge-notification"
                    (if this.AiResults.length "--has-results")
                  }}
                >{{this.AiResults.length}}</span>
              {{/if}}
            </div>
          </div>
        {{/if}}
      </div>
    </div>
  </template>
}
