(function() {

  window.Discourse.InviteModalView = window.Discourse.ModalBodyView.extend(Discourse.Presence, {
    templateName: 'modal/invite',
    title: Em.String.i18n('topic.invite_reply.title'),
    email: null,
    error: false,
    saving: false,
    finished: false,
    disabled: (function() {
      if (this.get('saving')) {
        return true;
      }
      if (this.blank('email')) {
        return true;
      }
      if (!Discourse.Utilities.emailValid(this.get('email'))) {
        return true;
      }
      return false;
    }).property('email', 'saving'),
    buttonTitle: (function() {
      if (this.get('saving')) {
        return Em.String.i18n('topic.inviting');
      }
      return Em.String.i18n('topic.invite_reply.title');
    }).property('saving'),
    successMessage: (function() {
      return Em.String.i18n('topic.invite_reply.success', {
        email: this.get('email')
      });
    }).property('email'),
    didInsertElement: function() {
      var _this = this;
      return Em.run.next(function() {
        return _this.$('input').focus();
      });
    },
    createInvite: function() {
      var _this = this;
      this.set('saving', true);
      this.set('error', false);
      this.get('topic').inviteUser(this.get('email')).then(function() {
        /* Success
        */
        _this.set('saving', false);
        return _this.set('finished', true);
      }, function() {
        /* Failure
        */
        _this.set('error', true);
        return _this.set('saving', false);
      });
      return false;
    }
  });

}).call(this);
