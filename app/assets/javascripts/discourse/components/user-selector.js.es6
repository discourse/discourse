import TextField from 'discourse/components/text-field';
import userSearch from 'discourse/lib/user-search';

export default TextField.extend({

  _initializeAutocomplete: function() {
    var self = this,
        selected = [],
        groups = [],
        currentUser = this.currentUser,
        includeMentionableGroups = this.get('includeMentionableGroups') === 'true',
        includeGroups = this.get('includeGroups') === 'true',
        allowedUsers = this.get('allowedUsers') === 'true';

    function excludedUsernames() {
      if (currentUser && self.get('excludeCurrentUser')) {
        return selected.concat([currentUser.get('username')]);
      }
      return selected;
    }

    this.$().val(this.get('usernames')).autocomplete({
      template: this.container.lookup('template:user-selector-autocomplete.raw'),
      disabled: this.get('disabled'),
      single: this.get('single'),
      allowAny: this.get('allowAny'),

      dataSource: function(term) {
        var results = userSearch({
          term: term.replace(/[^a-zA-Z0-9_\-\.]/, ''),
          topicId: self.get('topicId'),
          exclude: excludedUsernames(),
          includeGroups,
          allowedUsers,
          includeMentionableGroups
        });

        return results;
      },

      transformComplete: function(v) {
        if (v.username || v.name) {
          if (!v.username) { groups.push(v.name); }
          return v.username || v.name;
        } else {
          var excludes = excludedUsernames();
          return v.usernames.filter(function(item){
            return excludes.indexOf(item) === -1;
          });
        }
      },

      onChangeItems: function(items) {
        var hasGroups = false;
        items = items.map(function(i) {
          if (groups.indexOf(i) > -1) { hasGroups = true; }
          return i.username ? i.username : i;
        });
        self.set('usernames', items.join(","));
        self.set('hasGroups', hasGroups);

        selected = items;
      },

      reverseTransform: function(i) {
        return { username: i };
      }

    });
  }.on('didInsertElement'),

  _removeAutocomplete: function() {
    this.$().autocomplete('destroy');
  }.on('willDestroyElement'),

  // THIS IS A HUGE HACK TO SUPPORT CLEARING THE INPUT
  _clearInput: function() {
    if (arguments.length > 1) {
      if (Em.isEmpty(this.get("usernames"))) {
        this.$().parent().find("a").click();
      }
    }
  }.observes("usernames")

});
