/**
 A button to user preferences

 @class UserPreferencesButton
 @extends Discourse.ButtonView
 @namespace Discourse
 @module Discourse
 **/
Discourse.UserPreferencesButton = Discourse.ButtonView.extend({
  classNames: ['right'],
  textKey: 'user.preferences',

  click: function(){
    this.get('controller').transitionToRoute('preferences');
  },

  renderIcon: function(buffer) {
    buffer.push("<i class='fa fa-cog'></i>");
  }
});