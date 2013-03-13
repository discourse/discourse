/**
  This view handles rendering of a user's username preferences

  @class PreferencesUsernameView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.PreferencesUsernameView = Discourse.View.extend({
  templateName: 'user/username',
  classNames: ['user-preferences'],

  didInsertElement: function() {
    return $('#change_username').focus();
  },

  keyDown: function(e) {
    if (e.keyCode === 13) {
      if (!this.get('controller').get('saveDisabled')) {
        return this.get('controller').changeUsername();
      } else {
        e.preventDefault();
        return false;
      }
    }
  }

});


