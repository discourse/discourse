import TextField from 'discourse/components/text-field';
import userSearch from 'discourse/lib/user-search';

export default TextField.extend({

  _initializeAutocomplete: function() {
    var self = this,
        selected = [],
        currentUser = this.currentUser,
        includeGroups = this.get('includeGroups') === 'true';

    function excludedUsernames() {
      if (currentUser && self.get('excludeCurrentUser')) {
        return selected.concat([currentUser.get('username')]);
      }
      return selected;
    }

    var template = this.container.lookup('template:user-selector-autocomplete.raw');
    $(this.get('element')).val(this.get('usernames')).autocomplete({
      template: template,

      disabled: this.get('disabled'),
      single: this.get('single'),
      allowAny: this.get('allowAny'),

      dataSource: function(term) {
        term = term.replace(/[^a-zA-Z0-9_]/, '');
        return userSearch({
          term: term,
          topicId: self.get('topicId'),
          exclude: excludedUsernames(),
          includeGroups: includeGroups
        });
      },

      transformComplete: function(v) {
        if (v.username) {
          return v.username;
        } else {
          var excludes = excludedUsernames();
          return v.usernames.filter(function(item){
            return excludes.indexOf(item) === -1;
          });
        }
      },

      onChangeItems: function(items) {
        items = items.map(function(i) {
          return i.username ? i.username : i;
        });
        self.set('usernames', items.join(","));
        selected = items;
      },

      reverseTransform: function(i) {
        return { username: i };
      }

    });
  }.on('didInsertElement')

});
