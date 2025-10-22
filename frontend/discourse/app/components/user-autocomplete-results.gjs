import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { eq } from "truth-helpers";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import {
  callOnRenderCallback,
  handleAutocompleteResultClick,
} from "discourse/lib/autocomplete-result-helpers";
import { formatUsername } from "discourse/lib/utilities";
import scrollIntoView from "discourse/modifiers/scroll-into-view";

/**
 * Component for rendering user autocomplete results for the DAutocomplete modifier.
 *
 * This component handles rendering of users, emails, and groups in the autocomplete
 * dropdown, and is designed to be used with DAutocomplete's `component` API.
 *
 * @component UserAutocompleteResults
 * @param {Array} results - Array of autocomplete results (users, emails, groups)
 * @param {number} selectedIndex - Currently selected index in the results list
 * @param {Function} onSelect - Callback function triggered when a result is selected
 * @param {Function} onRender - Optional callback function triggered after component renders
 */
export default class UserAutocompleteResults extends Component {
  static TRIGGER_KEY = "@";

  @action
  handleResultClick(result, index, event) {
    // Use utility function for consistent behavior
    handleAutocompleteResultClick(this.args.onSelect, result, index, event);
  }

  @action
  handleInsert() {
    // Use utility function for onRender callback
    callOnRenderCallback(this.args.onRender, this.args.results);
  }

  @action
  handleUpdate() {
    // Use utility function for onRender callback
    callOnRenderCallback(this.args.onRender, this.args.results);
  }

  // TODO: initialRender hack might be needed here too to handle the scroll bug on first render
  // see hackery from:
  // https://github.com/discourse/discourse/blob/50f80d9809158f191e2b214ece7abd1cf298aab3/app/assets/javascripts/discourse/app/components/d-autocomplete-results.gjs#L118-L120
  <template>
    <div
      class="autocomplete ac-user"
      {{didInsert this.handleInsert}}
      {{didUpdate this.handleUpdate @selectedIndex}}
    >
      <ul>
        {{#each @results as |result index|}}
          {{#if result.isUser}}
            <li
              {{scrollIntoView
                (eq index @selectedIndex)
                (hash block="nearest" behavior="smooth")
              }}
            >
              <a
                href
                title={{result.name}}
                class={{if (eq index @selectedIndex) "selected"}}
                {{on "click" (fn this.handleResultClick result index)}}
              >
                {{avatar result imageSize="tiny"}}
                <span class="text-content">
                  <span class="username">{{formatUsername
                      result.username
                    }}</span>
                  {{#if result.name}}
                    <span class="name">{{result.name}}</span>
                  {{/if}}
                </span>
                {{#if result.status}}
                  <span class="user-status"></span>
                {{/if}}
              </a>
            </li>
          {{else if result.isEmail}}
            <li
              {{scrollIntoView
                (eq index @selectedIndex)
                (hash block="nearest" behavior="smooth")
              }}
            >
              <a
                href
                title={{result.username}}
                {{on "click" (fn this.handleResultClick result index)}}
              >
                {{icon "envelope"}}
                <span class="text-content username">{{formatUsername
                    result.username
                  }}</span>
              </a>
            </li>
          {{else if result.isGroup}}
            <li
              {{scrollIntoView
                (eq index @selectedIndex)
                (hash block="nearest" behavior="smooth")
              }}
            >
              <a
                href
                title={{result.full_name}}
                {{on "click" (fn this.handleResultClick result index)}}
              >
                {{icon "users"}}
                <span class="text-content">
                  <span class="username">{{result.name}}</span>
                  <span class="name">{{result.full_name}}</span>
                </span>
              </a>
            </li>
          {{/if}}
        {{/each}}
      </ul>
    </div>
  </template>
}
