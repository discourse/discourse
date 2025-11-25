import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { eq } from "discourse/truth-helpers";

/**
 * @typedef {import("discourse/lib/types/d-autocomplete").EmojiAutocompleteResult} EmojiAutocompleteResult
 */

/**
 * Component for rendering emoji autocomplete results for the DAutocomplete modifier.
 *
 * This component handles rendering of emojis in the autocomplete
 * dropdown, and is designed to be used with DAutocomplete's `component` API.
 *
 * @component EmojiAutocompleteResults
 * @implements {Component<import("discourse/lib/types/d-autocomplete").AutocompleteResultsSignature<EmojiAutocompleteResult>>}
 */
export default class EmojiAutocompleteResults extends Component {
  static TRIGGER_KEY = ":";

  @action
  handleResultClick(result, index, event) {
    event.preventDefault();
    event.stopPropagation();
    this.args.onSelect(result, index, event);
  }

  <template>
    <div class="autocomplete ac-emoji">
      <ul>
        {{#each @results as |result index|}}
          <li>
            <a
              href
              class={{if (eq index @selectedIndex) "selected"}}
              {{on "click" (fn this.handleResultClick result index)}}
            >
              <span class="text-content">
                {{#if result.src}}
                  <img src={{result.src}} class="emoji" />
                  <span class="emoji-shortname">{{result.code}}</span>
                {{else}}
                  {{result.label}}
                {{/if}}
              </span>
            </a>
          </li>
        {{/each}}
      </ul>
    </div>
  </template>
}
