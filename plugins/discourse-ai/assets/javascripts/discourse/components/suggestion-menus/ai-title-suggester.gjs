import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import DMenu from "discourse/float-kit/components/d-menu";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import {
  isAiCreditLimitError,
  popupAiCreditLimitError,
} from "../../lib/ai-errors";
import {
  MIN_CHARACTER_COUNT,
  showSuggestionsError,
} from "../../lib/ai-helper-suggestions";

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
      .querySelector(".composer-fields")
      ?.classList.toggle("showing-ai-suggestions", showTrigger);
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
    const data = {};

    if (this.content) {
      data.text = this.content;
    } else {
      data.topic_id = this.args.buffered.content.id;
    }

    try {
      const { suggestions } = await ajax(
        "/discourse-ai/ai-helper/suggest_title",
        { method: "POST", data }
      );

      this.suggestions = suggestions;

      if (suggestions?.length === 0) {
        showSuggestionsError(this, this.loadSuggestions.bind(this));
        return;
      }
    } catch (error) {
      if (isAiCreditLimitError(error)) {
        popupAiCreditLimitError(error);
      } else {
        popupAjaxError(error);
      }
    } finally {
      this.loading = false;
      this.triggerIcon = "rotate";
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
        @triggerClass="btn-transparent suggestion-button suggest-titles-button {{if
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
            <DropdownMenu as |dropdown|>
              {{#each this.suggestions as |suggestion index|}}
                <dropdown.item>
                  <DButton
                    @translatedLabel={{suggestion}}
                    @action={{fn this.applySuggestion suggestion}}
                    data-name={{suggestion}}
                    data-value={{index}}
                    title={{suggestion}}
                  />
                </dropdown.item>
              {{/each}}
            </DropdownMenu>
          {{/if}}
        </:content>
      </DMenu>
    {{/if}}
  </template>
}
