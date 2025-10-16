import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { htmlSafe } from "@ember/template";
import { eq } from "truth-helpers";
import BaseAutocompleteResults from "discourse/components/base-autocomplete-results";
import avatar from "discourse/helpers/avatar";
import { ajax } from "discourse/lib/ajax";
import { camelCaseToSnakeCase } from "discourse/lib/case-converter";
import { iconHTML } from "discourse/lib/icon-library";
import {
  emailValid,
  escapeExpression,
  formatUsername,
} from "discourse/lib/utilities";
import { CANCELLED_STATUS } from "discourse/modifiers/d-autocomplete";

/**
 * Component for rendering user autocomplete results
 * Extends BaseAutocompleteResults with user-specific functionality.
 *
 * @component UserAutocompleteResults
 * @extends BaseAutocompleteResults
 * @param {Array} results - Array of user results
 * @param {number} selectedIndex - Currently selected index
 * @param {Function} onSelect - Callback for item selection
 */
export default class UserAutocompleteResults extends BaseAutocompleteResults {
  /**
   * The trigger key for user autocomplete
   *
   * @type {string}
   * @static
   */
  static TRIGGER_KEY = "@";

  /**
   * Transform a selected user result to its username/name
   *
   * @param {Object} item - The selected user item
   * @returns {string} The username or name to insert
   * @static
   * @override
   */
  static transformComplete(item) {
    return item.username || item.name;
  }

  /**
   * The data source function for user autocomplete
   *
   * @param {string} term - The search term
   * @param {Object} options - Options for user search
   * @returns {Promise<Array>|null} The search results
   * @static
   * @override
   */
  static dataSource(term, options = {}) {
    if (term && term.match(/\s\s|\s$|[^\w\s@.-]/)) {
      return null;
    }

    // Handle @ prefix
    if (term && term.length > 0 && term[0] === "@") {
      term = term.substring(1);
    }

    return this._performDebouncedSearch(
      term,
      async (searchTerm) => {
        const searchOptions = {
          term: searchTerm,
          topicId: options.topicId,
          categoryId: options.categoryId,
          includeGroups: options.includeGroups,
          includeMentionableGroups: options.includeMentionableGroups,
          includeMessageableGroups: options.includeMessageableGroups,
          groupMembersOf: options.groupMembersOf,
          allowedUsers: options.allowedUsers,
          includeStagedUsers: options.includeStagedUsers,
          limit: options.limit || 6,
        };

        if (options.customUserSearchOptions) {
          Object.keys(options.customUserSearchOptions).forEach((key) => {
            searchOptions[camelCaseToSnakeCase(key)] =
              options.customUserSearchOptions[key];
          });
        }

        const response = await ajax("/u/search/users", { data: searchOptions });

        // Organize results
        const users = [];
        const emails = [];
        const groups = [];

        if (response.users) {
          response.users.forEach((user) => {
            if (!options.exclude?.includes(user.username)) {
              user.isUser = true;
              users.push(user);
            }
          });
        }

        if (options.allowEmails && emailValid(searchTerm)) {
          emails.push({ username: searchTerm, isEmail: true });
        }

        if (response.groups) {
          response.groups.forEach((group) => {
            if (!options.exclude?.includes(group.name)) {
              group.isGroup = true;
              groups.push(group);
            }
          });
        }

        return [...users, ...emails, ...groups];
      },
      options
    );
  }

  /**
   * Render a user item
   *
   * @param {Object} item - The user item
   * @param {number} index - The index of the item
   * @param {boolean} isSelected - Whether the item is selected
   * @returns {string} HTML for the user item
   */
  renderUserItem(item, index, isSelected) {
    const selectedClass = isSelected ? "selected" : "";
    const statusIcon = item.status ? '<span class="user-status"></span>' : "";

    return htmlSafe(`
      <li data-index="${index}" class="user-item ${selectedClass}">
        <a href title="${escapeExpression(item.name)}" class="${selectedClass}">
          ${avatar(item, { imageSize: "tiny" })}
          <span class="text-content">
            <span class="username">${escapeExpression(formatUsername(item.username))}</span>
            ${item.name ? `<span class="name">${escapeExpression(item.name)}</span>` : ""}
          </span>
          ${statusIcon}
        </a>
      </li>
    `);
  }

  /**
   * Render an email item
   *
   * @param {Object} item - The email item
   * @param {number} index - The index of the item
   * @param {boolean} isSelected - Whether the item is selected
   * @returns {string} HTML for the email item
   */
  renderEmailItem(item, index, isSelected) {
    const selectedClass = isSelected ? "selected" : "";

    return htmlSafe(`
      <li data-index="${index}" class="email-item ${selectedClass}">
        <a href title="${escapeExpression(item.username)}" class="${selectedClass}">
          ${iconHTML("envelope")}
          <span class="text-content username">${escapeExpression(formatUsername(item.username))}</span>
        </a>
      </li>
    `);
  }

  /**
   * Render a group item
   *
   * @param {Object} item - The group item
   * @param {number} index - The index of the item
   * @param {boolean} isSelected - Whether the item is selected
   * @returns {string} HTML for the group item
   */
  renderGroupItem(item, index, isSelected) {
    const selectedClass = isSelected ? "selected" : "";

    return htmlSafe(`
      <li data-index="${index}" class="group-item ${selectedClass}">
        <a href title="${escapeExpression(item.full_name || item.name)}" class="${selectedClass}">
          ${iconHTML("users")}
          <span class="text-content">
            <span class="username">${escapeExpression(item.name)}</span>
            ${item.full_name ? `<span class="name">${escapeExpression(item.full_name)}</span>` : ""}
          </span>
        </a>
      </li>
    `);
  }

  <template>
    <div class="autocomplete ac-user" {{didInsert this.handleInsert}}>
      <ul>
        {{#each @results as |result index|}}
          {{#if result.isUser}}
            <li
              class="user-item {{if (eq index @selectedIndex) 'selected'}}"
              data-index={{index}}
              {{on "click" (fn this.handleResultClick result index)}}
            >
              <a
                href="#"
                title={{result.name}}
                class={{if (eq index @selectedIndex) "selected"}}
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
              class="email-item {{if (eq index @selectedIndex) 'selected'}}"
              data-index={{index}}
              {{on "click" (fn this.handleResultClick result index)}}
            >
              <a
                href="#"
                title={{result.username}}
                class={{if (eq index @selectedIndex) "selected"}}
              >
                {{{iconHTML "envelope"}}}
                <span class="text-content username">{{formatUsername
                    result.username
                  }}</span>
              </a>
            </li>
          {{else if result.isGroup}}
            <li
              class="group-item {{if (eq index @selectedIndex) 'selected'}}"
              data-index={{index}}
              {{on "click" (fn this.handleResultClick result index)}}
            >
              <a
                href="#"
                title={{result.full_name}}
                class={{if (eq index @selectedIndex) "selected"}}
              >
                {{{iconHTML "users"}}}
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
