import { on, observes } from "ember-addons/ember-computed-decorators";
import TextField from "discourse/components/text-field";
import userSearch from "discourse/lib/user-search";
import { findRawTemplate } from "discourse/lib/raw-templates";

export default TextField.extend({
  autocorrect: false,
  autocapitalize: false,
  name: "user-selector",

  @observes("usernames")
  _update() {
    if (this.canReceiveUpdates === "true") {
      this._createAutocompleteInstance({ updateData: true });
    }
  },

  @on("willDestroyElement")
  _destroyAutocompleteInstance() {
    $(this.element).autocomplete("destroy");
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

    const excludedUsernames = () => {
      // hack works around some issues with allowAny eventing
      const usernames = single ? [] : selected;

      if (currentUser && excludeCurrentUser) {
        return usernames.concat([currentUser.username]);
      }
      return usernames;
    };

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
            exclude: excludedUsernames(),
            includeGroups,
            allowedUsers,
            includeMentionableGroups,
            includeMessageableGroups,
            group: userSelectorComponent.group,
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
            const excludes = excludedUsernames();
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

  // THIS IS A HUGE HACK TO SUPPORT CLEARING THE INPUT
  @observes("usernames")
  _clearInput() {
    if (arguments.length > 1 && Ember.isEmpty(this.usernames)) {
      $(this.element)
        .parent()
        .find("a")
        .click();
    }
  }
});
