/**
 A button for private message in user profile

 @class PrivateMessageButton
 @extends Discourse.ButtonView
 @namespace Discourse
 @module Discourse
 **/
Discourse.PrivateMessageButton = Discourse.ButtonView.extend({
  classNames: ['btn-primary'],
  textKey: 'user.private_message',

  click: function(){
    this.get('controller').send('composePrivateMessage');
  },

  renderIcon: function(buffer) {
    buffer.push("<i class='fa fa-envelope'></i>");
  }
});