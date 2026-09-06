import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DMenu from "discourse/float-kit/components/d-menu";
import { i18n } from "discourse-i18n";
import {
  fetchTitleSuggestions,
  MIN_CHARACTER_COUNT,
  showSuggestionsError,
} from "../../lib/ai-helper-suggestions";
import AiTitleSuggestionsList from "./ai-title-suggestions-list";

export default class AiTitleSuggester extends Component {
  @tracked loading = false;
  @tracked suggestions = null;
  @tracked triggerIcon = "discourse-sparkles";
  dMenu;

  get content() {
    return this.args.composer?.reply;
  }

  get showSuggestionButton() {
    const showTrigger =
      this.content?.length > MIN_CHARACTER_COUNT ||
      this.args.topicState === "edit";

    document
      .querySelector(".edit-topic-title")
      ?.classList.toggle("showing-ai-suggestions", showTrigger);

    return showTrigger;
  }

  get showDropdown() {
    return !this.loading && this.suggestions?.length > 0;
  }

  @action
  async loadSuggestions() {
    if (this.suggestions?.length > 0 && !this.dMenu.expanded) {
      return this.suggestions;
    }

    this.loading = true;
    this.triggerIcon = "spinner";

    const suggestions = await fetchTitleSuggestions({
      text: this.content,
      topicId: this.args.buffered?.content?.id,
    });

    this.loading = false;
    this.triggerIcon = "rotate";

    if (suggestions == null) {
      return;
    }

    this.suggestions = suggestions;

    if (suggestions.length === 0) {
      showSuggestionsError(this, this.loadSuggestions.bind(this));
      return;
    }

    return this.suggestions;
  }

  @action
  applySuggestion(suggestion) {
    const model = this.args.composer || this.args.buffered;
    if (!model) {
      return;
    }

    model.set("title", suggestion);
    this.dMenu.close();
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  onClose() {
    if (this.suggestions?.length > 0) {
      // If all suggestions have been used,
      // re-triggering when no suggestions present
      // will cause computation issues with
      // setting the icon, so we prevent it
      this.triggerIcon = "discourse-sparkles";
    }
  }

  <template>
    {{#if this.showSuggestionButton}}
      <DMenu
        @title={{i18n "discourse_ai.ai_helper.suggest"}}
        @icon={{this.triggerIcon}}
        @identifier="ai-title-suggester"
        @onClose={{this.onClose}}
        @triggerClass="suggestion-button suggest-titles-button {{if
          this.loading
          'is-loading'
        }}"
        @contentClass="ai-suggestions-menu"
        @onRegisterApi={{this.onRegisterApi}}
        @modalForMobile={{true}}
        @untriggers={{array}}
        {{on "click" this.loadSuggestions}}
      >
        <:content>
          {{#if this.showDropdown}}
            <AiTitleSuggestionsList
              @suggestions={{this.suggestions}}
              @onSelect={{this.applySuggestion}}
            />
          {{/if}}
        </:content>
      </DMenu>
    {{/if}}
  </template>
}
