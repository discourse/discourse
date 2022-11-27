import { bind, observes, on } from "discourse-common/utils/decorators";
import TextField from "discourse/components/text-field";
import { findRawTemplate } from "discourse-common/lib/raw-templates";
import { isEmpty } from "@ember/utils";
import userSearch from "discourse/lib/user-search";
import deprecated from "discourse-common/lib/deprecated";

export default TextField.extend({
  autocorrect: false,
  autocapitalize: false,
  name: "user-selector",
  canReceiveUpdates: false,
  single: false,
  fullWidthWrap: false,

  @on("init")
  deprecateComponent() {
    deprecated(
      "The `<UserSelector>` component is deprecated. Please use `<EmailGroupUserChooser>` instead.",
      { since: "2.7", dropFrom: "2.8", id: "discourse.user-selector-component" }
    );
  },

  @bind
  _paste(event) {
    let pastedText = "";

    if (window.clipboardData && window.clipboardData.getData) {
      // IE
      pastedText = window.clipboardData.getData("Text");
    } else if (event.clipboardData && event.clipboardData.getData) {
      pastedText = event.clipboardData.getData("text/plain");
    }

    if (pastedText.length > 0) {
      this.importText(pastedText);
      event.preventDefault();
      return false;
    }
  },

  didUpdateAttrs() {
    this._super(...arguments);

    if (this.canReceiveUpdates) {
      this._createAutocompleteInstance({ updateData: true });
    }
  },

  @on("willDestroyElement")
  _destroyAutocompleteInstance() {
    $(this.element).autocomplete("destroy");
    this.element.removeEventListener("paste", this._paste);
  },

  @on("didInsertElement")
  _createAutocompleteInstance(opts) {
    const bool = (n) => {
      const val = this[n];
      return val === true || val === "true";
    };

    let selected = [],
      groups = [],
      currentUser = this.currentUser,
      includeMentionableGroups = bool("includeMentionableGroups"),
      includeMessageableGroups = bool("includeMessageableGroups"),
      includeGroups = bool("includeGroups"),
      allowedUsers = bool("allowedUsers"),
      excludeCurrentUser = bool("excludeCurrentUser"),
      single = bool("single"),
      allowAny = bool("allowAny"),
      disabled = bool("disabled"),
      allowEmails = bool("allowEmails"),
      fullWidthWrap = bool("fullWidthWrap");

    const allExcludedUsernames = () => {
      // hack works around some issues with allowAny eventing
      let usernames = single ? [] : selected;

      if (currentUser && excludeCurrentUser) {
        usernames = usernames.concat([currentUser.username]);
      }

      return usernames.concat(this.excludedUsernames || []);
    };

    this.element.addEventListener("paste", this._paste);

    const userSelectorComponent = this;

    $(this.element)
      .val(this.usernames)
      .autocomplete({
        template: findRawTemplate("user-selector-autocomplete"),
        disabled,
        single,
        allowAny,
        updateData: opts && opts.updateData ? opts.updateData : false,
        fullWidthWrap,

        dataSource(term) {
          return userSearch({
            term,
            topicId: userSelectorComponent.topicId,
            exclude: allExcludedUsernames(),
            includeGroups,
            allowedUsers,
            includeMentionableGroups,
            includeMessageableGroups,
            groupMembersOf: userSelectorComponent.groupMembersOf,
            allowEmails,
          });
        },

        transformComplete(v) {
          if (v.username || v.name) {
            if (!v.username) {
              groups.push(v.name);
            }
            return v.username || v.name;
          } else {
            const excludes = allExcludedUsernames();
            return v.usernames.filter((item) => !excludes.includes(item));
          }
        },

        onChangeItems(items) {
          let hasGroups = false;
          items = items.map((i) => {
            if (groups.includes(i)) {
              hasGroups = true;
            }
            return i.username ? i.username : i;
          });

          let previouslySelected = [];
          if (Array.isArray(userSelectorComponent.usernames)) {
            previouslySelected = userSelectorComponent.usernames;
          } else {
            if (userSelectorComponent.usernames) {
              previouslySelected = userSelectorComponent.usernames.split(",");
            }
          }

          userSelectorComponent.setProperties({
            usernames: items.join(","),
            hasGroups,
          });
          selected = items;

          if (userSelectorComponent.onChangeCallback) {
            userSelectorComponent.onChangeCallback(
              previouslySelected,
              selected
            );
          }
        },

        reverseTransform(i) {
          return { username: i };
        },
      });
  },

  importText(text) {
    let usernames = [];
    if ((this.usernames || "").length > 0) {
      usernames = this.usernames.split(",");
    }

    (text || "").split(/[, \n]+/).forEach((val) => {
      val = val.replace(/^@+/, "").trim();
      if (
        val.length > 0 &&
        (!this.excludedUsernames || !this.excludedUsernames.includes(val))
      ) {
        usernames.push(val);
      }
    });
    this.set("usernames", usernames.uniq().join(","));

    if (!this.canReceiveUpdates) {
      this._createAutocompleteInstance({ updateData: true });
    }
  },

  // THIS IS A HUGE HACK TO SUPPORT CLEARING THE INPUT
  @observes("usernames")
  _clearInput() {
    if (arguments.length > 1 && isEmpty(this.usernames)) {
      $(this.element).parent().find("a").click();
    }
  },
});
