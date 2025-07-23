import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AssistantItem from "discourse/components/search-menu/results/assistant-item";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { isValidSearchTerm, translateResults } from "discourse/lib/search";
import { i18n } from "discourse-i18n";

export default class AiQuickSemanticSearch extends Component {
  static shouldRender(_args, { siteSettings }) {
    return siteSettings.ai_embeddings_semantic_quick_search_enabled;
  }

  @service search;
  @service quickSearch;
  @service siteSettings;

  @action
  async searchTermChanged() {
    if (!this.search.activeGlobalSearchTerm) {
      this.search.noResults = false;
      this.search.results = {};
      this.quickSearch.loading = false;
      this.quickSearch.invalidTerm = false;
    } else if (
      !isValidSearchTerm(this.search.activeGlobalSearchTerm, this.siteSettings)
    ) {
      this.search.noResults = true;
      this.search.results = {};
      this.quickSearch.loading = false;
      this.quickSearch.invalidTerm = true;
      return;
    } else {
      await this.performSearch();
    }
  }

  async performSearch() {
    this.quickSearch.loading = true;
    this.quickSearch.invalidTerm = false;

    try {
      const results = await ajax(`/discourse-ai/embeddings/quick-search`, {
        data: {
          q: this.search.activeGlobalSearchTerm,
        },
      });

      const searchResults = await translateResults(results);

      if (searchResults) {
        this.search.noResults = results.resultTypes.length === 0;
        this.search.results = searchResults;
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.quickSearch.loading = false;
    }
  }

  <template>
    {{yield}}

    {{#if this.search.activeGlobalSearchTerm}}
      <AssistantItem
        @suffix={{i18n "discourse_ai.embeddings.quick_search.suffix"}}
        @icon="discourse-sparkles"
        @closeSearchMenu={{@closeSearchMenu}}
        @searchTermChanged={{this.searchTermChanged}}
        @suggestionKeyword={{@suggestionKeyword}}
      />
    {{/if}}
  </template>
}
