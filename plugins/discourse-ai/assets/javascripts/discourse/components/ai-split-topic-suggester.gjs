import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import categoryBadge from "discourse/helpers/category-badge";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DMenu from "float-kit/components/d-menu";

export default class AiSplitTopicSuggester extends Component {
  @service site;

  @tracked suggestions = [];
  @tracked loading = false;
  @tracked icon = "discourse-sparkles";

  SUGGESTION_TYPES = {
    title: "suggest_title",
    category: "suggest_category",
    tag: "suggest_tags",
  };

  get input() {
    return this.args.selectedPosts.map((item) => item.cooked).join("\n");
  }

  get disabled() {
    return this.loading || this.suggestions.length > 0;
  }

  @action
  loadSuggestions() {
    if (this.loading || this.suggestions.length > 0) {
      return;
    }

    this.loading = true;

    ajax(`/discourse-ai/ai-helper/${this.args.mode}`, {
      method: "POST",
      data: { text: this.input },
    })
      .then((result) => {
        if (this.args.mode === this.SUGGESTION_TYPES.title) {
          this.suggestions = result.suggestions;
        } else if (this.args.mode === this.SUGGESTION_TYPES.category) {
          const suggestionIds = result.assistant.map((s) => s.id);
          const suggestedCategories = this.site.categories.filter((category) =>
            suggestionIds.includes(category.id)
          );
          this.suggestions = suggestedCategories;
        } else if (this.args.mode === this.SUGGESTION_TYPES.tag) {
          this.suggestions = result.assistant.map((s) => {
            return {
              name: s.name,
              count: s.count,
            };
          });
        }
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.loading = false;
      });
  }

  @action
  applySuggestion(suggestion, menu) {
    if (!this.args.mode) {
      return;
    }

    if (this.args.mode === this.SUGGESTION_TYPES.title) {
      this.args.updateAction(suggestion);
      return menu.close();
    }

    if (this.args.mode === this.SUGGESTION_TYPES.category) {
      this.args.updateAction(suggestion.id);
      return menu.close();
    }

    if (this.args.mode === this.SUGGESTION_TYPES.tag) {
      if (this.args.currentValue) {
        if (Array.isArray(this.args.currentValue)) {
          const updatedTags = [...this.args.currentValue, suggestion];
          this.args.updateAction([...new Set(updatedTags)]);
        } else {
          const updatedTags = [this.args.currentValue, suggestion];
          this.args.updateAction([...new Set(updatedTags)]);
        }
      } else {
        if (Array.isArray(suggestion)) {
          this.args.updateAction([...suggestion]);
        } else {
          this.args.updateAction([suggestion]);
        }
      }
      return menu.close();
    }
  }

  <template>
    {{#if this.loading}}
      {{!
        Dynamically changing @icon of DMenu
        causes it to rerender after load and
        close the menu once data is loaded.
        This workaround mimics an icon change of
        the button by adding an overlapping
        disabled button while loading}}
      <DButton
        class="ai-split-topic-loading-placeholder"
        @disabled={{true}}
        @icon="spinner"
      />
    {{/if}}
    <DMenu
      @icon="discourse-sparkles"
      @interactive={{true}}
      @identifier="ai-split-topic-suggestion-menu"
      class="ai-split-topic-suggestion-button"
      data-suggestion-mode={{@mode}}
      {{on "click" this.loadSuggestions}}
      as |menu|
    >
      <ul class="ai-split-topic-suggestion__results">
        {{#unless this.loading}}
          {{#each this.suggestions as |suggestion index|}}
            {{#if (eq @mode "suggest_category")}}
              <li
                data-name={{suggestion.name}}
                data-value={{suggestion.id}}
                class="ai-split-topic-suggestion__category-result"
                role="button"
                {{on "click" (fn this.applySuggestion suggestion menu)}}
              >
                {{categoryBadge suggestion}}
                <span class="topic-count">x
                  {{suggestion.totalTopicCount}}</span>
              </li>
            {{else if (eq @mode "suggest_tags")}}
              <li data-name={{suggestion.name}} data-value={{index}}>
                <DButton
                  @translatedLabel={{suggestion.name}}
                  @action={{fn this.applySuggestion suggestion.name menu}}
                >
                  <span class="topic-count">x{{suggestion.count}}</span>
                </DButton>
              </li>
            {{else}}
              <li data-name={{suggestion}} data-value={{index}}>
                <DButton
                  @translatedLabel={{suggestion}}
                  @action={{fn this.applySuggestion suggestion menu}}
                />
              </li>
            {{/if}}
          {{/each}}
        {{/unless}}
      </ul>
    </DMenu>
  </template>
}
