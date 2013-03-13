/**
  This view handles rendering of a user's private messages

  @class UserPrivateMessagesView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.UserPrivateMessagesView = Discourse.View.extend({
  templateName: 'user/private_messages',

  selectCurrent: function(evt) {
    var t;
    t = $(evt.currentTarget);
    t.closest('.action-list').find('li').removeClass('active');
    return t.closest('li').addClass('active');
  },

  inbox: function(evt) {
    this.selectCurrent(evt);
    return this.set('controller.filter', Discourse.UserAction.GOT_PRIVATE_MESSAGE);
  },

  sentMessages: function(evt) {
    this.selectCurrent(evt);
    return this.set('controller.filter', Discourse.UserAction.NEW_PRIVATE_MESSAGE);
  }

});


