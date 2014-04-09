/**
 A button for user invited in user profile

 @class UserInvitedButton
 @extends Discourse.ButtonView
 @namespace Discourse
 @module Discourse
 **/
Discourse.UserInvitedButton = Discourse.ButtonView.extend({
  classNames: ['right'],
  textKey: 'user.invited.title',

  click: function(){
    this.get('controller').transitionToRoute('user.invited');
  },

  renderIcon: function(buffer) {
    buffer.push("<i class='fa fa-envelope-o'></i>");
  }
});

//{{#link-to 'user.invited' class="btn right"}}<i class='fa fa-envelope-o'></i>{{i18n user.invited.title}}{{/link-to}}