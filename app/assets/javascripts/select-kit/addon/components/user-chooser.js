import userSearch, {
  eagerCompleteSearch,
  skipSearch,
} from "discourse/lib/user-search";
import MultiSelectComponent from "select-kit/components/multi-select";
import { computed } from "@ember/object";
import { isPresent } from "@ember/utils";
import { makeArray } from "discourse-common/lib/helpers";

export const CUSTOM_USER_SEARCH_OPTIONS = [];

export default MultiSelectComponent.extend({
  pluginApiIdentifiers: ["user-chooser"],
  classNames: ["user-chooser"],
  valueProperty: "username",

  modifyComponentForRow() {
    return "user-chooser/user-row";
  },

  selectKitOptions: {
    topicId: undefined,
    categoryId: undefined,
    includeGroups: false,
    allowedUsers: false,
    includeMentionableGroups: false,
    includeMessageableGroups: false,
    allowEmails: false,
    groupMembersOf: undefined,
    excludeCurrentUser: false,
    customSearchOptions: undefined,
  },

  content: computed("value.[]", function () {
    return makeArray(this.value).map((x) => this.defaultItem(x, x));
  }),

  excludedUsers: computed(
    "value",
    "currentUser",
    "selectKit.options.{excludeCurrentUser,excludedUsernames}",
    {
      get() {
        const options = this.selectKit.options;
        let usernames = makeArray(this.value);

        if (this.currentUser && options.excludeCurrentUser) {
          usernames = usernames.concat([this.currentUser.username]);
        }

        return usernames.concat(options.excludedUsernames || []);
      },
    }
  ),

  search(filter = "") {
    filter = filter || "";
    filter = filter.replace(/^@/, "");
    const options = this.selectKit.options;
    if (filter === "" && options?.customSearchOptions?.defaultSearchResults) {
      return Promise.resolve(options.customSearchOptions.defaultSearchResults);
    }

    // prevents doing ajax request for nothing
    const skippedSearch = skipSearch(filter, options.allowEmails);
    const eagerComplete = eagerCompleteSearch(
      filter,
      options.topicId || options.categoryId
    );
    if (skippedSearch || (filter === "" && !eagerComplete)) {
      return;
    }

    let customUserSearchOptions = {};
    if (options.customSearchOptions && isPresent(CUSTOM_USER_SEARCH_OPTIONS)) {
      customUserSearchOptions = CUSTOM_USER_SEARCH_OPTIONS.reduce(
        (obj, option) => {
          return {
            ...obj,
            [option]: options.customSearchOptions[option],
          };
        },
        {}
      );
    }

    return userSearch({
      term: filter,
      topicId: options.topicId,
      categoryId: options.categoryId,
      exclude: this.excludedUsers,
      includeGroups: options.includeGroups,
      allowedUsers: options.allowedUsers,
      includeMentionableGroups: options.includeMentionableGroups,
      includeMessageableGroups: options.includeMessageableGroups,
      groupMembersOf: options.groupMembersOf,
      allowEmails: options.allowEmails,
      includeStagedUsers: this.includeStagedUsers,
      customUserSearchOptions,
    }).then((result) => {
      if (typeof result === "string") {
        // do nothing promise probably got cancelled
      } else {
        return result;
      }
    });
  },
});
