/**
  This view handles rendering of a user's email preferences

  @class PreferencesEmailView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.PreferencesEmailView = Discourse.View.extend({
  templateName: 'user/email',
  classNames: ['user-preferences'],
  didInsertElement: function() {
    return $('#change_email').focus();
  }
});


