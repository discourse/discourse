/**
  A modal view for inviting a user to Discourse

  @class InviteView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.InviteView = Discourse.ModalBodyView.extend({
  templateName: 'modal/invite',
  title: Em.String.i18n('topic.invite_reply.title'),


  keyUp: function(e) {
    // Add the invitee if they hit enter
    if (e.keyCode === 13) { this.get('controller').createInvite(); }
    return false;
  }

});


