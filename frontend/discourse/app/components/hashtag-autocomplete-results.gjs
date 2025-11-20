// @ts-check

import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import categoryLink from "discourse/helpers/category-link";
import icon from "discourse/helpers/d-icon";
import scrollIntoView from "discourse/modifiers/scroll-into-view";
import { eq } from "discourse/truth-helpers";

/**
 * @typedef {import("discourse/lib/types/d-autocomplete").AutocompleteResultsSignature} AutocompleteResultsSignature
 */

/**
 * Component for rendering hashtag autocomplete results for the DAutocomplete modifier.
 *
 * This component handles rendering of categories and tags in the autocomplete
 * dropdown, and is designed to be used with DAutocomplete's `component` API.
 *
 * @component HashtagAutocompleteResults
 * @implements {Component<AutocompleteResultsSignature>}
 */
export default class HashtagAutocompleteResults extends Component {
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

  @action
  getResultLabel(result) {
    if (result.model) {
      return categoryLink(result.model, {
        allowUncategorized: true,
        link: false,
      });
    }

    return `${result.name} x ${result.count}`;
  }

  <template>
    <div
      class="autocomplete ac-category-or-tag"
      {{didInsert this.handleInsert}}
      {{didUpdate this.handleUpdate @selectedIndex}}
    >
      <ul>
        {{#each @results as |result index|}}
          <li {{scrollIntoView (this.shouldScroll index)}}>
            <a
              href
              class={{if (eq index @selectedIndex) "selected"}}
              {{on "click" (fn this.handleResultClick result index)}}
            >
              {{#unless result.model}}
                {{icon "tag"}}
              {{/unless}}
              <span class="text-content">{{this.getResultLabel result}}</span>
            </a>
          </li>
        {{/each}}
      </ul>
    </div>
  </template>
}
