import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { MODIFIER_REGEXP } from "discourse/components/search-menu";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { isValidSearchTerm, translateResults } from "discourse/lib/search";

const MAX_RESULTS_FOR_ADDING_AI = 3;

export default class AiQuickSearch extends Component {
  static shouldRender(args, { siteSettings }) {
    return siteSettings.ai_embeddings_semantic_quick_search_enabled;
  }

  @service appEvents;
  @service search;
  @service siteSettings;

  @tracked hasAiResults = false;
  @tracked searchingWithAi = false;
  @tracked lastSearchTerm = null;

  markAiResults = modifier(() => {
    if (!this.hasAiResults) {
      return;
    }

    const resultTypes = this.search.results?.resultTypes || [];
    resultTypes.forEach((resultType) => {
      resultType.results?.forEach((result) => {
        if (result.aiGenerated) {
          const topicId = result.topic?.id || result.topic_id;
          if (topicId) {
            document
              .querySelector(
                `.search-menu .list .item [data-topic-id="${topicId}"]`
              )
              ?.closest(".item")
              ?.classList.add("ai-search-result");
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
  onInsert() {
    const resultTypes = this.search.results?.resultTypes || [];
    const hasExistingAiResults = resultTypes.some((resultType) =>
      resultType.results?.some((result) => result.aiGenerated)
    );

    if (hasExistingAiResults) {
      this.lastSearchTerm = this.search.activeGlobalSearchTerm;
      this.hasAiResults = true;
    }
  }

  @action
  onSearchTermChange() {
    this.hasAiResults = false;
    this.searchingWithAi = false;
    this.lastSearchTerm = null;
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

    this.appEvents.trigger("ai-quick-search:state-changed", {
      searching: true,
    });

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
      this.appEvents.trigger("ai-quick-search:state-changed", {
        searching: false,
      });
    }
  }

  #removeExistingAiResults() {
    if (!this.search.results) {
      return;
    }

    if (this.search.results.posts) {
      this.search.results.posts = this.search.results.posts.filter(
        (post) => !post.aiGenerated
      );
    }

    const resultTypes = this.search.results.resultTypes || [];
    resultTypes.forEach((resultType) => {
      if (resultType.results) {
        resultType.results = resultType.results.filter(
          (result) => !result.aiGenerated
        );
      }
    });
  }

  #getExistingTopicIds() {
    const existingTopicIds = new Set();
    const resultTypes = this.search.results?.resultTypes || [];

    resultTypes.forEach((resultType) => {
      resultType.results?.forEach((result) => {
        const topicId = result.topic?.id || result.topic_id;
        if (topicId) {
          existingTopicIds.add(topicId);
        }
      });
    });

    return existingTopicIds;
  }

  appendResults(aiResults) {
    if (!this.search.results) {
      this.search.results = {};
    }

    this.#removeExistingAiResults();

    const existingTopicIds = this.#getExistingTopicIds();
    const uniqueAiPosts = aiResults.posts.filter((post) => {
      const topicId = post.topic?.id || post.topic_id;
      return !existingTopicIds.has(topicId);
    });

    if (uniqueAiPosts.length === 0) {
      return;
    }

    this.search.results.posts = [
      ...(this.search.results.posts || []),
      ...uniqueAiPosts,
    ];

    const resultTypes = this.search.results.resultTypes || [];
    const topicResultType = resultTypes.find((rt) => rt.type === "topic");

    if (topicResultType) {
      topicResultType.results = [...topicResultType.results, ...uniqueAiPosts];
    } else {
      resultTypes.push({
        results: uniqueAiPosts,
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
      {{didInsert this.onInsert}}
      {{didUpdate this.onSearchTermChange this.search.activeGlobalSearchTerm}}
      {{didUpdate this.checkAndAddAiResults this.totalResults}}
      {{this.markAiResults}}
    >
    </div>
  </template>
}
