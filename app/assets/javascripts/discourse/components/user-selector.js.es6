import { isEmpty } from "@ember/utils";
import { on, observes } from "discourse-common/utils/decorators";
import TextField from "discourse/components/text-field";
import userSearch from "discourse/lib/user-search";
import { findRawTemplate } from "discourse/lib/raw-templates";

export default TextField.extend({
  autocorrect: false,
  autocapitalize: false,
  name: "user-selector",

  init() {
    this._super();
    this._paste = e => {
      let pastedText = "";
      if (window.clipboardData && window.clipboardData.getData) {
        // IE
        pastedText = window.clipboardData.getData("Text");
      } else if (e.clipboardData && e.clipboardData.getData) {
        pastedText = e.clipboardData.getData("text/plain");
      }

      if (pastedText.length > 0) {
        this.importText(pastedText);
        e.preventDefault();
        return false;
      }
    };
  },

  @observes("usernames")
  _update() {
    if (this.canReceiveUpdates === "true") {
      this._createAutocompleteInstance({ updateData: true });
    }
  },

  @on("willDestroyElement")
  _destroyAutocompleteInstance() {
    $(this.element).autocomplete("destroy");
    this.element.addEventListener("paste", this._paste);
  },

  @on("didInsertElement")
  _createAutocompleteInstance(opts) {
    const bool = n => {
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
        usernames.concat([currentUser.username]);
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
            allowEmails
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
            return v.usernames.filter(item => excludes.indexOf(item) === -1);
          }
        },

        onChangeItems(items) {
          let hasGroups = false;
          items = items.map(i => {
            if (groups.indexOf(i) > -1) {
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
            hasGroups
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
        }
      });
  },

  importText(text) {
    let usernames = [];
    if ((this.usernames || "").length > 0) {
      usernames = this.usernames.split(",");
    }

    (text || "").split(/[, \n]+/).forEach(val => {
      val = val.replace(/^@+/, "").trim();
      if (
        val.length > 0 &&
        (!this.excludedUsernames || !this.excludedUsernames.includes(val))
      ) {
        usernames.push(val);
      }
    });
    this.set("usernames", usernames.uniq().join(","));
    if (this.canReceiveUpdates !== "true") {
      this._createAutocompleteInstance({ updateData: true });
    }
  },

  // THIS IS A HUGE HACK TO SUPPORT CLEARING THE INPUT
  @observes("usernames")
  _clearInput() {
    if (arguments.length > 1 && isEmpty(this.usernames)) {
      $(this.element)
        .parent()
        .find("a")
        .click();
    }
  }
});
