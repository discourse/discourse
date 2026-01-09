// @ts-check

import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { htmlSafe } from "@ember/template";
import scrollIntoView from "discourse/modifiers/scroll-into-view";
import { eq } from "discourse/truth-helpers";

/**
 * @typedef {import("discourse/lib/types/d-autocomplete").RichHashtagAutocompleteResult} RichHashtagAutocompleteResult
 */

/**
 * Component for rendering rich hashtag autocomplete results for the DAutocomplete modifier.
 *
 * This component handles rendering of hashtags with rich metadata (icons, colors, descriptions)
 * for categories, tags, and other contextual types in composer contexts.
 * Designed to be used with DAutocomplete's `component` API.
 *
 * @component RichHashtagAutocompleteResults
 * @implements {Component<import("discourse/lib/types/d-autocomplete").AutocompleteResultsSignature<RichHashtagAutocompleteResult>>}
 */
export default class RichHashtagAutocompleteResults extends Component {
  static TRIGGER_KEY = "#";

  @tracked isInitialRender = true;

  @action
  handleResultClick(result, index, event) {
    event.preventDefault();
    event.stopPropagation();
    this.args.onSelect(result, index, event);
  }

  @action
  handleInsert() {
    this.args.onRender?.(this.args.results);
  }

  @action
  handleUpdate() {
    this.isInitialRender = false;
    this.args.onRender?.(this.args.results);
  }

  @action
  shouldScroll(index) {
    return index === this.args.selectedIndex && !this.isInitialRender;
  }

  <template>
    <div
      class="autocomplete hashtag-autocomplete"
      {{didInsert this.handleInsert}}
      {{didUpdate this.handleUpdate @selectedIndex}}
    >
      <div class="hashtag-autocomplete__fadeout">
        <ul>
          {{#each @results as |result index|}}
            <li
              class="hashtag-autocomplete__option"
              {{scrollIntoView (this.shouldScroll index)}}
            >
              <a
                class="hashtag-autocomplete__link
                  {{if (eq index @selectedIndex) 'selected'}}"
                title={{result.description}}
                href
                {{on "click" (fn this.handleResultClick result index)}}
              >
                {{htmlSafe result.iconHtml}}
                <span class="hashtag-autocomplete__text">
                  {{result.text}}
                  {{#if result.secondary_text}}
                    <span
                      class="hashtag-autocomplete__meta-text"
                    >({{result.secondary_text}})</span>
                  {{/if}}
                </span>
              </a>
            </li>
          {{/each}}
        </ul>
      </div>
    </div>
  </template>
}
