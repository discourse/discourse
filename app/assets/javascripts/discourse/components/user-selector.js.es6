import { observes } from "ember-addons/ember-computed-decorators";
import TextField from "discourse/components/text-field";
import userSearch from "discourse/lib/user-search";
import { findRawTemplate } from "discourse/lib/raw-templates";

export default TextField.extend({
  autocorrect: false,
  autocapitalize: false,
  name: "user-selector",

  @observes("usernames")
  _update() {
    if (this.get("canReceiveUpdates") === "true")
      this.didInsertElement({ updateData: true });
  },

  didInsertElement(opts) {
    this._super(...arguments);

    const bool = n => {
      const val = this.get(n);
      return val === true || val === "true";
    };

    var self = this,
      selected = [],
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
      disallowEmails = bool("disallowEmails");

    function excludedUsernames() {
      // hack works around some issues with allowAny eventing
      const usernames = single ? [] : selected;

      if (currentUser && excludeCurrentUser) {
        return usernames.concat([currentUser.get("username")]);
      }
      return usernames;
    }

    this.$()
      .val(this.get("usernames"))
      .autocomplete({
        template: findRawTemplate("user-selector-autocomplete"),
        disabled: disabled,
        single: single,
        allowAny: allowAny,
        updateData: opts && opts.updateData ? opts.updateData : false,

        dataSource(term) {
          var results = userSearch({
            term,
            topicId: self.get("topicId"),
            exclude: excludedUsernames(),
            includeGroups,
            allowedUsers,
            includeMentionableGroups,
            includeMessageableGroups,
            group: self.get("group"),
            disallowEmails
          });
          return results;
        },

        transformComplete(v) {
          if (v.username || v.name) {
            if (!v.username) {
              groups.push(v.name);
            }
            return v.username || v.name;
          } else {
            var excludes = excludedUsernames();
            return v.usernames.filter(function(item) {
              return excludes.indexOf(item) === -1;
            });
          }
        },

        onChangeItems(items) {
          var hasGroups = false;
          items = items.map(function(i) {
            if (groups.indexOf(i) > -1) {
              hasGroups = true;
            }
            return i.username ? i.username : i;
          });
          self.set("usernames", items.join(","));
          self.set("hasGroups", hasGroups);

          selected = items;
          if (self.get("onChangeCallback")) self.onChangeCallback();
        },

        reverseTransform(i) {
          return { username: i };
        }
      });
  },

  willDestroyElement() {
    this._super(...arguments);
    this.$().autocomplete("destroy");
  },

  // THIS IS A HUGE HACK TO SUPPORT CLEARING THE INPUT
  @observes("usernames")
  _clearInput: function() {
    if (arguments.length > 1) {
      if (Ember.isEmpty(this.get("usernames"))) {
        this.$()
          .parent()
          .find("a")
          .click();
      }
    }
  }
});
