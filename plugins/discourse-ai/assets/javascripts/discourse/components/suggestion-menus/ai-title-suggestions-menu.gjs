import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { fetchTitleSuggestions } from "../../lib/ai-helper-suggestions";
import AiTitleSuggestionsList from "./ai-title-suggestions-list";

export default class AiTitleSuggestionsMenu extends Component {
  @tracked loading = true;
  @tracked suggestions = null;

  get model() {
    return this.args.data.model;
  }

  get noResults() {
    return this.suggestions?.length === 0;
  }

  @action
  async loadSuggestions() {
    this.loading = true;

    const suggestions = await fetchTitleSuggestions({
      text: this.model?.reply,
    });

    this.loading = false;

    if (suggestions == null) {
      this.args.close();
      return;
    }

    this.suggestions = suggestions;
  }

  @action
  applySuggestion(suggestion) {
    this.model?.set("title", suggestion);
    this.args.close();
  }

  <template>
    <div class="ai-suggestions-menu" {{didInsert this.loadSuggestions}}>
      {{#if this.loading}}
        <div class="ai-suggestions-menu__loading">{{dIcon "spinner"}}</div>
      {{else if this.suggestions.length}}
        <AiTitleSuggestionsList
          @onSelect={{this.applySuggestion}}
          @suggestions={{this.suggestions}}
        />
      {{else if this.noResults}}
        <div class="ai-suggestions-menu__empty">
          <span class="ai-suggestions-menu__empty-text">
            {{i18n "discourse_ai.ai_helper.suggest_errors.no_suggestions"}}
          </span>
          <DButton
            class="btn-small btn-transparent --primary"
            @action={{this.loadSuggestions}}
            @icon="rotate"
            @label="discourse_ai.ai_helper.context_menu.regen"
          />
        </div>
      {{/if}}
    </div>
  </template>
}
