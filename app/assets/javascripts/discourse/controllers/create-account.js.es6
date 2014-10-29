import ModalFunctionality from 'discourse/mixins/modal-functionality';

import DiscourseController from 'discourse/controllers/controller';

export default DiscourseController.extend(ModalFunctionality, {
  needs: ['login'],

  uniqueUsernameValidation: null,
  globalNicknameExists: false,
  complete: false,
  accountPasswordConfirm: 0,
  accountChallenge: 0,
  formSubmitted: false,
  rejectedEmails: Em.A([]),
  rejectedPasswords: Em.A([]),
  prefilledUsername: null,
  userFields: null,

  hasAuthOptions: Em.computed.notEmpty('authOptions'),
  canCreateLocal: Discourse.computed.setting('enable_local_logins'),
  showCreateForm: Em.computed.or('hasAuthOptions', 'canCreateLocal'),
  maxUsernameLength: Discourse.computed.setting('max_username_length'),
  minUsernameLength: Discourse.computed.setting('min_username_length'),

  resetForm: function() {

    // We wrap the fields in a structure so we can assign a value
    this.setProperties({
      accountName: '',
      accountEmail: '',
      accountUsername: '',
      accountPassword: '',
      authOptions: null,
      globalNicknameExists: false,
      complete: false,
      formSubmitted: false,
      rejectedEmails: [],
      rejectedPasswords: [],
      prefilledUsername: null,
    });
    this._createUserFields();
  },

  submitDisabled: function() {
    if (!this.get('passwordRequired')) return false; // 3rd party auth
    if (this.get('formSubmitted')) return true;
    if (this.get('nameValidation.failed')) return true;
    if (this.get('emailValidation.failed')) return true;
    if (this.get('usernameValidation.failed')) return true;
    if (this.get('passwordValidation.failed')) return true;

    // Validate required fields
    var userFields = this.get('userFields');
    if (userFields) { userFields = userFields.filterProperty('field.required'); }
    if (!Ember.empty(userFields)) {
      var anyEmpty = userFields.any(function(uf) {
        var val = uf.get('value');
        return !val || Ember.empty(val);
      });
      if (anyEmpty) { return true; }
    }
    return false;
  }.property('passwordRequired', 'nameValidation.failed', 'emailValidation.failed', 'usernameValidation.failed', 'passwordValidation.failed', 'formSubmitted', 'userFields.@each.value'),

  passwordRequired: function() {
    return this.blank('authOptions.auth_provider');
  }.property('authOptions.auth_provider'),

  passwordInstructions: function() {
    return I18n.t('user.password.instructions', {count: Discourse.SiteSettings.min_password_length});
  }.property(),

  // Validate the name. It's not required.
  nameValidation: function() {
    if (this.get('accountPasswordConfirm') === 0) {
      this.fetchConfirmationValue();
    }

    return Discourse.InputValidation.create({ok: true});
  }.property('accountName'),

  // Check the email address
  emailValidation: function() {
    // If blank, fail without a reason
    var email;
    if (this.blank('accountEmail')) {
      return Discourse.InputValidation.create({
        failed: true
      });
    }

    email = this.get("accountEmail");

    if (this.get('rejectedEmails').contains(email)) {
      return Discourse.InputValidation.create({
        failed: true,
        reason: I18n.t('user.email.invalid')
      });
    }

    if ((this.get('authOptions.email') === email) && this.get('authOptions.email_valid')) {
      return Discourse.InputValidation.create({
        ok: true,
        reason: I18n.t('user.email.authenticated', {
          provider: this.get('authOptions.auth_provider')
        })
      });
    }

    if (Discourse.Utilities.emailValid(email)) {
      return Discourse.InputValidation.create({
        ok: true,
        reason: I18n.t('user.email.ok')
      });
    }

    return Discourse.InputValidation.create({
      failed: true,
      reason: I18n.t('user.email.invalid')
    });
  }.property('accountEmail', 'rejectedEmails.@each'),

  emailValidated: function() {
    return this.get('authOptions.email') === this.get("accountEmail") && this.get('authOptions.email_valid');
  }.property('accountEmail', 'authOptions.email', 'authOptions.email_valid'),

  prefillUsername: function() {
    if (this.get('prefilledUsername')) {
      // If username field has been filled automatically, and email field just changed,
      // then remove the username.
      if (this.get('accountUsername') === this.get('prefilledUsername')) {
        this.set('accountUsername', '');
      }
      this.set('prefilledUsername', null);
    }
    if (this.get('emailValidation.ok') && (this.blank('accountUsername') || this.get('authOptions.email'))) {
      // If email is valid and username has not been entered yet,
      // or email and username were filled automatically by 3rd parth auth,
      // then look for a registered username that matches the email.
      this.fetchExistingUsername();
    }
  }.observes('emailValidation', 'accountEmail'),

  fetchExistingUsername: Discourse.debounce(function() {
    var self = this;
    Discourse.User.checkUsername(null, this.get('accountEmail')).then(function(result) {
      if (result.suggestion && (self.blank('accountUsername') || self.get('accountUsername') === self.get('authOptions.username'))) {
        self.set('accountUsername', result.suggestion);
        self.set('prefilledUsername', result.suggestion);
      }
    });
  }, 500),

  usernameMatch: function() {
    if (this.usernameNeedsToBeValidatedWithEmail()) {
      if (this.get('emailValidation.failed')) {
        if (this.shouldCheckUsernameMatch()) {
          return this.set('uniqueUsernameValidation', Discourse.InputValidation.create({
            failed: true,
            reason: I18n.t('user.username.enter_email')
          }));
        } else {
          return this.set('uniqueUsernameValidation', Discourse.InputValidation.create({ failed: true }));
        }
      } else if (this.shouldCheckUsernameMatch()) {
        this.set('uniqueUsernameValidation', Discourse.InputValidation.create({
          failed: true,
          reason: I18n.t('user.username.checking')
        }));
        return this.checkUsernameAvailability();
      }
    }
  }.observes('accountEmail'),

  basicUsernameValidation: function() {
    this.set('uniqueUsernameValidation', null);

    if (this.get('accountUsername') === this.get('prefilledUsername')) {
      return Discourse.InputValidation.create({
        ok: true,
        reason: I18n.t('user.username.prefilled')
      });
    }

    // If blank, fail without a reason
    if (this.blank('accountUsername')) {
      return Discourse.InputValidation.create({
        failed: true
      });
    }

    // If too short
    if (this.get('accountUsername').length < Discourse.SiteSettings.min_username_length) {
      return Discourse.InputValidation.create({
        failed: true,
        reason: I18n.t('user.username.too_short')
      });
    }

    // If too long
    if (this.get('accountUsername').length > this.get('maxUsernameLength')) {
      return Discourse.InputValidation.create({
        failed: true,
        reason: I18n.t('user.username.too_long')
      });
    }

    this.checkUsernameAvailability();
    // Let's check it out asynchronously
    return Discourse.InputValidation.create({
      failed: true,
      reason: I18n.t('user.username.checking')
    });
  }.property('accountUsername'),

  shouldCheckUsernameMatch: function() {
    return !this.blank('accountUsername') && this.get('accountUsername').length >= this.get('minUsernameLength');
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
              reason: I18n.t('user.username.global_match')
            }));
          } else {
            return _this.set('uniqueUsernameValidation', Discourse.InputValidation.create({
              ok: true,
              reason: I18n.t('user.username.available')
            }));
          }
        } else {
          if (result.suggestion) {
            if (result.global_match !== void 0 && result.global_match === false) {
              _this.set('globalNicknameExists', true);
              return _this.set('uniqueUsernameValidation', Discourse.InputValidation.create({
                failed: true,
                reason: I18n.t('user.username.global_mismatch', result)
              }));
            } else {
              return _this.set('uniqueUsernameValidation', Discourse.InputValidation.create({
                failed: true,
                reason: I18n.t('user.username.not_available', result)
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
              reason: I18n.t('user.username.enter_email')
            }));
          }
        }
      });
    }
  }, 500),

  // Actually wait for the async name check before we're 100% sure we're good to go
  usernameValidation: function() {
    var basicValidation, uniqueUsername;
    basicValidation = this.get('basicUsernameValidation');
    uniqueUsername = this.get('uniqueUsernameValidation');
    if (uniqueUsername) {
      return uniqueUsername;
    }
    return basicValidation;
  }.property('uniqueUsernameValidation', 'basicUsernameValidation'),

  usernameNeedsToBeValidatedWithEmail: function() {
    return( this.get('globalNicknameExists') || false );
  },

  // Validate the password
  passwordValidation: function() {
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
    if (password.length < Discourse.SiteSettings.min_password_length) {
      return Discourse.InputValidation.create({
        failed: true,
        reason: I18n.t('user.password.too_short')
      });
    }

    if (this.get('rejectedPasswords').contains(password)) {
      return Discourse.InputValidation.create({
        failed: true,
        reason: I18n.t('user.password.common')
      });
    }

    // Looks good!
    return Discourse.InputValidation.create({
      ok: true,
      reason: I18n.t('user.password.ok')
    });
  }.property('accountPassword', 'rejectedPasswords.@each'),

  fetchConfirmationValue: function() {
    var createAccountController = this;
    return Discourse.ajax('/users/hp.json').then(function (json) {
      createAccountController.set('accountPasswordConfirm', json.value);
      createAccountController.set('accountChallenge', json.challenge.split("").reverse().join(""));
    });
  },

  actions: {
    externalLogin: function(provider) {
      this.get('controllers.login').send('externalLogin', provider);
    },

    createAccount: function() {
      var self = this,
          attrs = this.getProperties('accountName', 'accountEmail', 'accountPassword', 'accountUsername', 'accountPasswordConfirm', 'accountChallenge'),
          userFields = this.get('userFields');

      // Add the userfields to the data
      if (!Em.empty(userFields)) {
        attrs.userFields = {};
        userFields.forEach(function(f) {
          attrs.userFields[f.get('field.id')] = f.get('value');
        });
      }

      this.set('formSubmitted', true);
      return Discourse.User.createAccount(attrs).then(function(result) {
        if (result.success) {
          // Trigger the browser's password manager using the hidden static login form:
          var $hidden_login_form = $('#hidden-login-form');
          $hidden_login_form.find('input[name=username]').val(attrs.accountUsername);
          $hidden_login_form.find('input[name=password]').val(attrs.accountPassword);
          $hidden_login_form.find('input[name=redirect]').val(Discourse.getURL('/users/account-created'));
          $hidden_login_form.submit();
        } else {
          self.flash(result.message || I18n.t('create_account.failed'), 'error');
          if (result.errors && result.errors.email && result.errors.email.length > 0 && result.values) {
            self.get('rejectedEmails').pushObject(result.values.email);
          }
          if (result.errors && result.errors.password && result.errors.password.length > 0) {
            self.get('rejectedPasswords').pushObject(attrs.accountPassword);
          }
          self.set('formSubmitted', false);
        }
        if (result.active && !Discourse.SiteSettings.must_approve_users) {
          return window.location.reload();
        }
      }, function() {
        self.set('formSubmitted', false);
        return self.flash(I18n.t('create_account.failed'), 'error');
      });
    }
  },

  _createUserFields: function() {
    if (!this.site) { return; }

    var userFields = this.site.get('user_fields');
    if (userFields) {
      userFields = userFields.map(function(f) {
        return Ember.Object.create({
          value: null,
          field: f
        });
      });
    }
    this.set('userFields', userFields);
  }.on('init')

});
