import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { htmlSafe } from "@ember/template";
import { and, eq, not } from "truth-helpers";
import { safeInvoke } from "discourse/lib/function-utils";
import scrollIntoView from "discourse/modifiers/scroll-into-view";

/**
 * Component for rendering rich hashtag autocomplete results for the DAutocomplete modifier.
 *
 * This component handles rendering of hashtags with rich metadata (icons, colors, descriptions)
 * for categories, tags, and other contextual types in composer contexts.
 * Designed to be used with DAutocomplete's `component` API.
 *
 * @component RichHashtagAutocompleteResults
 * @param {Array} results - Array of rich hashtag results with type, icon, text, secondary_text, description
 * @param {number} selectedIndex - Currently selected index in the results list
 * @param {Function} onSelect - Callback function triggered when a result is selected
 * @param {Function} onRender - Optional callback function triggered after component renders
 */
export default class RichHashtagAutocompleteResults extends Component {
  static TRIGGER_KEY = "#";

  @tracked isInitialRender = true;

  @action
  handleResultClick(result, index, event) {
    event.preventDefault();
    event.stopPropagation();
    safeInvoke(this.args.onSelect, result, index, event);
  }

  @action
  handleInsert() {
    safeInvoke(this.args.onRender, this.args.results);
  }

  @action
  handleUpdate() {
    this.isInitialRender = false;
    safeInvoke(this.args.onRender, this.args.results);
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
              {{scrollIntoView
                (and (not this.isInitialRender) (eq index @selectedIndex))
              }}
            >
              <a
                class="hashtag-autocomplete__link
                  {{if (eq index @selectedIndex) 'selected'}}"
                title={{result.description}}
                href
                {{on "click" (fn this.handleResultClick result index)}}
              >
                {{htmlSafe result.icon}}
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
