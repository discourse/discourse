/**
  This view handles rendering of a user's bio editor

  @class PreferencesAboutView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.PreferencesAboutView = Discourse.View.extend({
  templateName: 'user/about',
  classNames: ['user-preferences'],

  didInsertElement: function() {
    this.$('textarea').focus();
  }
});


