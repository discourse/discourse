/**
  This view handles the create account modal

  @class CreateAccountView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.CreateAccountView = Discourse.ModalBodyView.extend({
  templateName: 'modal/create_account',
  title: Em.String.i18n('create_account.title'),
  uniqueUsernameValidation: null,
  globalNicknameExists: false,
  complete: false,
  accountPasswordConfirm: 0,
  accountChallenge: 0,
  formSubmitted: false,

  submitDisabled: (function() {
    if (this.get('formSubmitted')) return true;
    if (this.get('nameValidation.failed')) return true;
    if (this.get('emailValidation.failed')) return true;
    if (this.get('usernameValidation.failed')) return true;
    if (this.get('passwordValidation.failed')) return true;
    return false;
  }).property('nameValidation.failed', 'emailValidation.failed', 'usernameValidation.failed', 'passwordValidation.failed', 'formSubmitted'),

  passwordRequired: (function() {
    return this.blank('authOptions.auth_provider');
  }).property('authOptions.auth_provider'),

  // Validate the name
  nameValidation: (function() {

    // If blank, fail without a reason
    if (this.blank('accountName')) return Discourse.InputValidation.create({ failed: true });

    if (this.get('accountPasswordConfirm') === 0) {
      this.fetchConfirmationValue();
    }

    // If too short
    if (this.get('accountName').length < 3) {
      return Discourse.InputValidation.create({
        failed: true,
        reason: Em.String.i18n('user.name.too_short')
      });
    }

    // Looks good!
    return Discourse.InputValidation.create({
      ok: true,
      reason: Em.String.i18n('user.name.ok')
    });
  }).property('accountName'),

  // Check the email address
  emailValidation: (function() {
    // If blank, fail without a reason
    var email;
    if (this.blank('accountEmail')) {
      return Discourse.InputValidation.create({
        failed: true
      });
    }

    email = this.get("accountEmail");
    if ((this.get('authOptions.email') === email) && this.get('authOptions.email_valid')) {
      return Discourse.InputValidation.create({
        ok: true,
        reason: Em.String.i18n('user.email.authenticated', {
          provider: this.get('authOptions.auth_provider')
        })
      });
    }

    if (Discourse.Utilities.emailValid(email)) {
      return Discourse.InputValidation.create({
        ok: true,
        reason: Em.String.i18n('user.email.ok')
      });
    }

    return Discourse.InputValidation.create({
      failed: true,
      reason: Em.String.i18n('user.email.invalid')
    });
  }).property('accountEmail'),

  usernameMatch: (function() {
    if (this.usernameNeedsToBeValidatedWithEmail()) {
      if (this.get('emailValidation.failed')) {
        if (this.shouldCheckUsernameMatch()) {
          return this.set('uniqueUsernameValidation', Discourse.InputValidation.create({
            failed: true,
            reason: Em.String.i18n('user.username.enter_email')
          }));
        } else {
          return this.set('uniqueUsernameValidation', Discourse.InputValidation.create({ failed: true }));
        }
      } else if (this.shouldCheckUsernameMatch()) {
        this.set('uniqueUsernameValidation', Discourse.InputValidation.create({
          failed: true,
          reason: Em.String.i18n('user.username.checking')
        }));
        return this.checkUsernameAvailability();
      }
    }
  }).observes('accountEmail'),

  basicUsernameValidation: (function() {
    this.set('uniqueUsernameValidation', null);

    // If blank, fail without a reason
    if (this.blank('accountUsername')) {
      return Discourse.InputValidation.create({
        failed: true
      });
    }

    // If too short
    if (this.get('accountUsername').length < 3) {
      return Discourse.InputValidation.create({
        failed: true,
        reason: Em.String.i18n('user.username.too_short')
      });
    }

    // If too long
    if (this.get('accountUsername').length > 15) {
      return Discourse.InputValidation.create({
        failed: true,
        reason: Em.String.i18n('user.username.too_long')
      });
    }

    this.checkUsernameAvailability();
    // Let's check it out asynchronously
    return Discourse.InputValidation.create({
      failed: true,
      reason: Em.String.i18n('user.username.checking')
    });
  }).property('accountUsername'),

  shouldCheckUsernameMatch: function() {
    return !this.blank('accountUsername') && this.get('accountUsername').length > 2;
  },

  checkUsernameAvailability: Discourse.debounce(function() {
    var _this = this;
    if (this.shouldCheckUsernameMatch()) {
      return Discourse.User.checkUsername(this.get('accountUsername'), this.get('accountEmail')).then(function(result) {
        _this.set('globalNicknameExists', false);
        if (result.available) {
          if (result.global_match) {
            _this.set('globalNicknameExists', true);
            return _this.set('uniqueUsernameValidation', Discourse.InputValidation.create({
              ok: true,
              reason: Em.String.i18n('user.username.global_match')
            }));
          } else {
            return _this.set('uniqueUsernameValidation', Discourse.InputValidation.create({
              ok: true,
              reason: Em.String.i18n('user.username.available')
            }));
          }
        } else {
          if (result.suggestion) {
            if (result.global_match !== void 0 && result.global_match === false) {
              _this.set('globalNicknameExists', true);
              return _this.set('uniqueUsernameValidation', Discourse.InputValidation.create({
                failed: true,
                reason: Em.String.i18n('user.username.global_mismatch', result)
              }));
            } else {
              return _this.set('uniqueUsernameValidation', Discourse.InputValidation.create({
                failed: true,
                reason: Em.String.i18n('user.username.not_available', result)
              }));
            }
          } else if (result.errors) {
            return _this.set('uniqueUsernameValidation', Discourse.InputValidation.create({
              failed: true,
              reason: result.errors.join(' ')
            }));
          } else {
            _this.set('globalNicknameExists', true);
            return _this.set('uniqueUsernameValidation', Discourse.InputValidation.create({
              failed: true,
              reason: Em.String.i18n('user.username.enter_email')
            }));
          }
        }
      });
    }
  }, 500),

  // Actually wait for the async name check before we're 100% sure we're good to go
  usernameValidation: (function() {
    var basicValidation, uniqueUsername;
    basicValidation = this.get('basicUsernameValidation');
    uniqueUsername = this.get('uniqueUsernameValidation');
    if (uniqueUsername) {
      return uniqueUsername;
    }
    return basicValidation;
  }).property('uniqueUsernameValidation', 'basicUsernameValidation'),

  usernameNeedsToBeValidatedWithEmail: function() {
    return( this.get('globalNicknameExists') || false );
  },

  // Validate the password
  passwordValidation: (function() {
    var password;
    if (!this.get('passwordRequired')) {
      return Discourse.InputValidation.create({
        ok: true
      });
    }

    // If blank, fail without a reason
    password = this.get("accountPassword");
    if (this.blank('accountPassword')) {
      return Discourse.InputValidation.create({ failed: true });
    }

    // If too short
    if (password.length < 6) {
      return Discourse.InputValidation.create({
        failed: true,
        reason: Em.String.i18n('user.password.too_short')
      });
    }

    // Looks good!
    return Discourse.InputValidation.create({
      ok: true,
      reason: Em.String.i18n('user.password.ok')
    });
  }).property('accountPassword'),

  fetchConfirmationValue: function() {
    var createAccountView = this;
    return Discourse.ajax('/users/hp.json').then(function (json) {
      createAccountView.set('accountPasswordConfirm', json.value);
      createAccountView.set('accountChallenge', json.challenge.split("").reverse().join(""));
    });
  },

  createAccount: function() {
    var challenge, email, name, password, passwordConfirm, username,
      _this = this;
    this.set('formSubmitted', true);
    name = this.get('accountName');
    email = this.get('accountEmail');
    password = this.get('accountPassword');
    username = this.get('accountUsername');
    passwordConfirm = this.get('accountPasswordConfirm');
    challenge = this.get('accountChallenge');
    return Discourse.User.createAccount(name, email, password, username, passwordConfirm, challenge).then(function(result) {
      if (result.success) {
        _this.flash(result.message);
        _this.set('complete', true);
      } else {
        _this.flash(result.message || Em.String.i18n('create_account.failed'), 'error');
        _this.set('formSubmitted', false);
      }
      if (result.active) {
        return window.location.reload();
      }
    }, function() {
      _this.set('formSubmitted', false);
      return _this.flash(Em.String.i18n('create_account.failed'), 'error');
    });
  },

  didInsertElement: function(e) {
    // allows the submission the form when pressing 'ENTER' on *any* text input field
    // but only when the submit button is enabled
    var createAccountView = this;
    Em.run.schedule('afterRender', function() {
      $("input[type='text'], input[type='password']").keydown(function(e) {
        if (createAccountView.get('submitDisabled') === false && e.keyCode === 13) {
          createAccountView.createAccount();
        }
      });
    });
  }

});
