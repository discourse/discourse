/**
 A button for logout

 @class LogoutButton
 @extends Discourse.ButtonView
 @namespace Discourse
 @module Discourse
 **/
Discourse.LogoutButton = Discourse.ButtonView.extend({
  classNames: ['btn-danger', 'right'],
  textKey: 'user.log_out',

  click: function(){
    this.get('controller').send('logout');
  },

  renderIcon: function(buffer) {
    buffer.push("<i class='fa fa-sign-out'></i>");
  }
});