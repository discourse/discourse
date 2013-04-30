/**
  A modal view for inviting a user to private message

  @class InvitePrivateModalView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.InvitePrivateModalView = Discourse.ModalBodyView.extend({
  templateName: 'modal/invite_private',
  title: Em.String.i18n('topic.invite_private.title'),
  email: null,
  error: false,
  saving: false,
  finished: false,

  disabled: (function() {
    if (this.get('saving')) return true;
    return this.blank('emailOrUsername');
  }).property('emailOrUsername', 'saving'),

  buttonTitle: (function() {
    if (this.get('saving')) return Em.String.i18n('topic.inviting');
    return Em.String.i18n('topic.invite_private.action');
  }).property('saving'),

  didInsertElement: function() {
    var _this = this;
    return Em.run.next(function() {
      return _this.$('input').focus();
    });
  },

  invite: function() {
    var _this = this;
    this.set('saving', true);
    this.set('error', false);
    // Invite the user to the private message
    this.get('topic').inviteUser(this.get('emailOrUsername')).then(function() {
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


