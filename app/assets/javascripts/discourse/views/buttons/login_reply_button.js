/**
  A button prompting users to login to reply to a topic

  @class LoginReplyButton
  @extends Discourse.ButtonView
  @namespace Discourse
  @module Discourse
**/
Discourse.LoginReplyButton = Discourse.ButtonView.extend({
  textKey: 'topic.login_reply',
  classNames: ['btn', 'btn-primary', 'create'],
  click: function() {
    this.get('controller').send('showLogin');
  }
});