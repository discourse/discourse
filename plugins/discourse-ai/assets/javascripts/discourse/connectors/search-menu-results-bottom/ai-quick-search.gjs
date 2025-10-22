import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { MODIFIER_REGEXP } from "discourse/components/search-menu";
import loadingSpinner from "discourse/helpers/loading-spinner";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { isValidSearchTerm, translateResults } from "discourse/lib/search";

const MAX_RESULTS_FOR_ADDING_AI = 3;

export default class AiQuickSearch extends Component {
  static shouldRender(args, { siteSettings }) {
    return siteSettings.ai_embeddings_semantic_quick_search_enabled;
  }

  @service search;
  @service siteSettings;

  @tracked hasAiResults = false;
  @tracked searchingWithAi = false;
  @tracked lastSearchTerm = null;

  markAiResults = modifier(() => {
    if (!this.hasAiResults) {
      return;
    }

    const resultsContainer = document.querySelector(".search-menu .results");
    if (resultsContainer) {
      resultsContainer.classList.add("has-ai-search-results");
    }

    const resultTypes = this.search.results?.resultTypes || [];
    resultTypes.forEach((resultType) => {
      resultType.results?.forEach((result) => {
        if (result.aiGenerated) {
          const topicId = result.topic?.id || result.topic_id;
          if (topicId) {
            const listItem = document
              .querySelector(
                `.search-menu .list .item [data-topic-id="${topicId}"]`
              )
              ?.closest(".item");

            if (listItem) {
              listItem.classList.add("ai-search-result");
            }
          }
        }
      });
    });
  });

  get totalResults() {
    const resultTypes = this.search.results?.resultTypes || [];
    return resultTypes.reduce(
      (sum, type) => sum + (type.results?.length || 0),
      0
    );
  }

  get hasModifiers() {
    const term = this.search.activeGlobalSearchTerm || "";
    return MODIFIER_REGEXP.test(term);
  }

  get shouldAddAiResults() {
    const searchingForTopics = this.args.outletArgs?.searchTopics;
    const hasSearched = this.search.results !== undefined;

    return (
      !this.hasAiResults &&
      !this.searchingWithAi &&
      searchingForTopics &&
      hasSearched &&
      isValidSearchTerm(
        this.search.activeGlobalSearchTerm,
        this.siteSettings
      ) &&
      this.totalResults <= MAX_RESULTS_FOR_ADDING_AI &&
      !this.hasModifiers &&
      !this.search.inTopicContext
    );
  }

  @action
  onSearchTermChange() {
    this.hasAiResults = false;
    this.searchingWithAi = false;
    this.lastSearchTerm = null;

    const resultsContainer = document.querySelector(".search-menu .results");
    if (resultsContainer) {
      resultsContainer.classList.remove("has-ai-search-results");
    }
  }

  @action
  async checkAndAddAiResults() {
    const currentTerm = this.search.activeGlobalSearchTerm;
    if (this.lastSearchTerm === currentTerm) {
      return;
    }

    if (this.shouldAddAiResults) {
      this.lastSearchTerm = currentTerm;
      await this.performAiSearch();
    }
  }

  async performAiSearch() {
    this.searchingWithAi = true;

    if (this.totalResults === 0) {
      this.search.noResults = false;
    }

    try {
      const results = await ajax("/discourse-ai/embeddings/quick-search", {
        data: {
          q: this.search.activeGlobalSearchTerm,
        },
      });

      const searchResults = await translateResults(results);

      if (searchResults?.posts?.length > 0) {
        searchResults.posts.forEach((post) => {
          post.aiGenerated = true;
        });

        this.appendResults(searchResults);
        this.hasAiResults = true;
      } else {
        this.search.noResults = true;
      }
    } catch (error) {
      popupAjaxError(error);
      if (this.totalResults === 0) {
        this.search.noResults = true;
      }
    } finally {
      this.searchingWithAi = false;
    }
  }

  appendResults(aiResults) {
    if (!this.search.results) {
      this.search.results = {};
    }

    this.search.results.posts = [
      ...(this.search.results.posts || []),
      ...aiResults.posts,
    ];

    const resultTypes = this.search.results.resultTypes || [];
    const topicResultType = resultTypes.find((rt) => rt.type === "topic");

    if (topicResultType) {
      topicResultType.results = [
        ...topicResultType.results,
        ...aiResults.posts,
      ];
    } else {
      resultTypes.push({
        results: aiResults.posts,
        componentName: "search-result-topic",
        type: "topic",
        more: false,
      });
    }

    this.search.results.resultTypes = resultTypes;
    this.search.results = { ...this.search.results };
    this.search.noResults = false;
  }

  <template>
    <div
      {{didUpdate this.onSearchTermChange this.search.activeGlobalSearchTerm}}
      {{didUpdate this.checkAndAddAiResults this.totalResults}}
      {{this.markAiResults}}
    >
      {{#if this.searchingWithAi}}
        <div class="ai-quick-search-loading">
          <div class="ai-quick-search-loading__content">
            {{loadingSpinner}}
          </div>
        </div>
      {{/if}}
    </div>
  </template>
}
