import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { SEARCH_TYPE_DEFAULT } from "discourse/controllers/full-page-search";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { isValidSearchTerm, translateResults } from "discourse/lib/search";
import { i18n } from "discourse-i18n";
import DTooltip from "float-kit/components/d-tooltip";
import AiIndicatorWave from "./ai-indicator-wave";

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
  initialSearchTerm = this.args.searchTerm;

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

    this.initialSearchTerm = this.args.searchTerm;
    this.searching = true;
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

    // Auto-enabled and showing results:
    if (
      this.autoEnabledForZeroResults &&
      this.showingAiResults &&
      this.AiResults.length > 0
    ) {
      return i18n(
        "discourse_ai.embeddings.semantic_search_results.zero_results_expanded",
        {
          count: this.AiResults.length,
        }
      );
    }

    // Search loading:
    if (this.searching) {
      return i18n("discourse_ai.embeddings.semantic_search_loading");
    }

    // We have results and we are showing them
    if (this.AiResults.length && this.showingAiResults) {
      return i18n("discourse_ai.embeddings.semantic_search_results.toggle", {
        count: this.AiResults.length,
      });
    }

    // We have results but are hiding them
    if (this.AiResults.length && !this.showingAiResults) {
      return i18n(
        "discourse_ai.embeddings.semantic_search_results.toggle_hidden",
        {
          count: this.AiResults.length,
        }
      );
    }

    // Typing to search:
    if (
      this.AiResults.length === 0 &&
      this.searchTerm !== this.initialSearchTerm
    ) {
      return i18n("discourse_ai.embeddings.semantic_search_results.new");
    }

    // No results:
    if (this.AiResults.length === 0) {
      return i18n("discourse_ai.embeddings.semantic_search_results.none");
    }
  }

  get settled() {
    return (
      this.validSearchOrder &&
      !this.searching &&
      this.searchTerm === this.initialSearchTerm
    );
  }

  get noResults() {
    return this.settled && this.AiResults.length === 0;
  }

  get searchTerm() {
    if (this.initialSearchTerm !== this.args.searchTerm) {
      this.initialSearchTerm = undefined;
    }

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

  get tooltipText() {
    return i18n(
      `discourse_ai.embeddings.semantic_search_tooltips.${
        this.validSearchOrder ? "results_explanation" : "invalid_sort"
      }`
    );
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
            {{icon "discourse-sparkles"}}
            {{this.searchStateText}}
          </div>

          {{#if this.validSearchOrder}}
            <AiIndicatorWave @loading={{this.searching}} />
          {{/if}}

          <DTooltip
            @identifier="semantic-search-tooltip"
            class="semantic-search__tooltip"
          >
            <:trigger>
              {{icon "far-circle-question"}}
            </:trigger>
            <:content>
              {{this.tooltipText}}
            </:content>
          </DTooltip>
        </div>
      </div>
    </div>
  </template>
}
