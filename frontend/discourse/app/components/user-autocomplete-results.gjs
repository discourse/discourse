// @ts-check

import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { formatUsername } from "discourse/lib/utilities";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dScrollIntoView from "discourse/ui-kit/modifiers/d-scroll-into-view";

/**
 * @typedef {import("discourse/lib/types/d-autocomplete").UserEmailGroupResult} UserEmailGroupResult
 */

/**
 * Component for rendering user autocomplete results for the DAutocomplete modifier.
 *
 * This component handles rendering of users, emails, and groups in the autocomplete
 * dropdown, and is designed to be used with DAutocomplete's `component` API.
 *
 * @component UserAutocompleteResults
 * @implements {Component<import("discourse/lib/types/d-autocomplete").AutocompleteResultsSignature<UserEmailGroupResult>>}
 */
export default class UserAutocompleteResults extends Component {
  static TRIGGER_KEY = "@";

  @tracked isInitialRender = true;

  /**
   * @param {UserEmailGroupResult} result
   * @param {number} index
   * @param {Event} event
   */
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

  /** @param {number} index */
  @action
  shouldScroll(index) {
    return index === this.args.selectedIndex && !this.isInitialRender;
  }

  /** @param {number} index */
  @action
  shouldSelect(index) {
    return index === this.args.selectedIndex;
  }

  /** @param {UserEmailGroupResult} result */
  @action
  getTitle(result) {
    if (result.isUser === true) {
      return result.name;
    }
    if (result.isEmail === true) {
      return result.username;
    }
    return result.full_name;
  }

  /**
   * @param {UserEmailGroupResult} result
   * @param {number} index
   */
  @action
  getItemLinkClasses(result, index) {
    let classes = "";

    // Only users carry custom classes.
    if (result.isUser === true && result.cssClasses) {
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
            {{dScrollIntoView (this.shouldScroll index)}}
          >
            <a
              class={{this.getItemLinkClasses result index}}
              href
              title={{this.getTitle result}}
              {{on "click" (fn this.handleResultClick result index)}}
            >
              {{#if result.isUser}}
                {{dAvatar result imageSize="tiny"}}
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
                {{dIcon "envelope"}}
                <span class="text-content username">{{formatUsername
                    result.username
                  }}</span>
              {{else if result.isGroup}}
                {{dIcon "users"}}
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
