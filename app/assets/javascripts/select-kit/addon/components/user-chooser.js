import userSearch, {
  eagerCompleteSearch,
  skipSearch,
} from "discourse/lib/user-search";
import MultiSelectComponent from "select-kit/components/multi-select";
import { computed } from "@ember/object";
import { makeArray } from "discourse-common/lib/helpers";

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

    // prevents doing ajax request for nothing
    const skippedSearch = skipSearch(filter, options.allowEmails);
    const eagerComplete = eagerCompleteSearch(
      filter,
      options.topicId || options.categoryId
    );
    if (skippedSearch || (filter === "" && !eagerComplete)) {
      return;
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
    }).then((result) => {
      if (typeof result === "string") {
        // do nothing promise probably got cancelled
      } else {
        return result;
      }
    });
  },
});
