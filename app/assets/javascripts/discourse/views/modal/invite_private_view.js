/**
  A modal view for inviting a user to private message

  @class InvitePrivateView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.InvitePrivateView = Discourse.ModalBodyView.extend({
  templateName: 'modal/invite_private',
  title: Em.String.i18n('topic.invite_private.title'),

  keyUp: function(e) {
    // Add the invitee if they hit enter
    if (e.keyCode === 13) { this.get('controller').invite(); }
    return false;
  }

});


