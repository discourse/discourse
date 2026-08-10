import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import {
  fetchTitleSuggestions,
  showSuggestionsError,
} from "../../lib/ai-helper-suggestions";
import AiTitleSuggestionsList from "./ai-title-suggestions-list";

export default class AiTitleSuggestionsMenu extends Component {
  @tracked loading = true;
  @tracked suggestions = null;

  get model() {
    return this.args.data.model;
  }

  @action
  async loadSuggestions() {
    this.loading = true;

    const suggestions = await fetchTitleSuggestions({
      text: this.model?.reply,
      topicId: this.model?.id,
    });

    this.loading = false;

    if (suggestions == null) {
      this.args.close();
      return;
    }

    this.suggestions = suggestions;

    if (suggestions.length === 0) {
      showSuggestionsError(this, this.loadSuggestions.bind(this));
    }
  }

  @action
  applySuggestion(suggestion) {
    this.model?.set("title", suggestion);
    this.args.close();
  }

  <template>
    <div {{didInsert this.loadSuggestions}}>
      <DConditionalLoadingSpinner @condition={{this.loading}}>
        {{#if this.suggestions.length}}
          <AiTitleSuggestionsList
            @suggestions={{this.suggestions}}
            @onSelect={{this.applySuggestion}}
          />
        {{/if}}
      </DConditionalLoadingSpinner>
    </div>
  </template>
}
