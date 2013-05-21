/**
  A modal view for inviting a user to Discourse

  @class InviteModalView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.InviteModalView = Discourse.ModalBodyView.extend({
  templateName: 'modal/invite',
  title: Em.String.i18n('topic.invite_reply.title'),
  email: null,
  error: false,
  saving: false,
  finished: false,

  disabled: (function() {
    if (this.get('saving')) return true;
    if (this.blank('email')) return true;
    if (!Discourse.Utilities.emailValid(this.get('email'))) return true;
    return false;
  }).property('email', 'saving'),

  buttonTitle: (function() {
    if (this.get('saving')) return Em.String.i18n('topic.inviting');
    return Em.String.i18n('topic.invite_reply.action');
  }).property('saving'),

  successMessage: (function() {
    return Em.String.i18n('topic.invite_reply.success', {
      email: this.get('email')
    });
  }).property('email'),

  didInsertElement: function() {
    var inviteModalView = this;
    Em.run.schedule('afterRender', function() {
      inviteModalView.$('input').focus();
    });
  },

  createInvite: function() {
    var _this = this;
    this.set('saving', true);
    this.set('error', false);
    this.get('topic').inviteUser(this.get('email')).then(function() {
      // Success
      _this.set('saving', false);
      return _this.set('finished', true);
    }, function() {
      // Failure
      _this.set('error', true);
      return _this.set('saving', false);
    });
    return false;
  }
});


