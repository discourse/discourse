import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
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

  static RESULT_TYPE_CONFIG = {
    isUser: {
      titleKey: "name",
      hasCustomClasses: true,
    },
    isEmail: {
      titleKey: "username",
    },
    isGroup: {
      titleKey: "full_name",
    },
  };

  @tracked isInitialRender = true;

  @action
  handleResultClick(result, index, event) {
    event.preventDefault();
    event.stopPropagation();
    this.args.onSelect(result, index, event);
  }

  @action
  handleInsert() {
    this.args.onRender(this.args.results);
  }

  @action
  handleUpdate() {
    this.isInitialRender = false;
    this.args.onRender(this.args.results);
  }

  @action
  shouldScroll(index) {
    return index === this.args.selectedIndex && !this.isInitialRender;
  }

  @action
  shouldSelect(index) {
    return index === this.args.selectedIndex;
  }

  getResultConfig(result) {
    for (const [key, config] of Object.entries(
      UserAutocompleteResults.RESULT_TYPE_CONFIG
    )) {
      if (result[key]) {
        return config;
      }
    }
  }

  @action
  getTitle(result) {
    const config = this.getResultConfig(result);
    return result[config.titleKey];
  }

  @action
  getItemLinkClasses(result, index) {
    const config = this.getResultConfig(result);
    let classes = "";

    if (config.hasCustomClasses && result.cssClasses) {
      classes = result.cssClasses;
    }

    if (this.shouldSelect(index)) {
      classes = classes ? `${classes} selected` : "selected";
    }

    return classes;
  }

  <template>
    <div
      class="autocomplete ac-user"
      {{didInsert this.handleInsert}}
      {{didUpdate this.handleUpdate @selectedIndex}}
    >
      <ul>
        {{#each @results as |result index|}}
          <li
            data-index={{result.index}}
            {{scrollIntoView (this.shouldScroll index)}}
          >
            <a
              href
              title={{this.getTitle result}}
              class={{this.getItemLinkClasses result index}}
              {{on "click" (fn this.handleResultClick result index)}}
            >
              {{#if result.isUser}}
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
              {{else if result.isEmail}}
                {{icon "envelope"}}
                <span class="text-content username">{{formatUsername
                    result.username
                  }}</span>
              {{else if result.isGroup}}
                {{icon "users"}}
                <span class="text-content">
                  <span class="username">{{result.name}}</span>
                  <span class="name">{{result.full_name}}</span>
                </span>
              {{/if}}
            </a>
          </li>
        {{/each}}
      </ul>
    </div>
  </template>
}
