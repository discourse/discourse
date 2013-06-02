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

  didInsertElement: function() {
    this._super();

    var inviteModalView = this;
    Em.run.schedule('afterRender', function() {
      inviteModalView.$('input').focus();
    });
  }

});


