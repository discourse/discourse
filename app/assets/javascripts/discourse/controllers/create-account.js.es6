import { ajax } from 'discourse/lib/ajax';
import ModalFunctionality from 'discourse/mixins/modal-functionality';
import { setting } from 'discourse/lib/computed';
import { on } from 'ember-addons/ember-computed-decorators';
import { emailValid } from 'discourse/lib/utilities';
import InputValidation from 'discourse/models/input-validation';
import PasswordValidation from "discourse/mixins/password-validation";
import UsernameValidation from "discourse/mixins/username-validation";

export default Ember.Controller.extend(ModalFunctionality, PasswordValidation, UsernameValidation, {
  login: Ember.inject.controller(),

  complete: false,
  accountPasswordConfirm: 0,
  accountChallenge: 0,
  formSubmitted: false,
  rejectedEmails: Em.A([]),
  prefilledUsername: null,
  userFields: null,
  isDeveloper: false,

  hasAuthOptions: Em.computed.notEmpty('authOptions'),
  canCreateLocal: setting('enable_local_logins'),
  showCreateForm: Em.computed.or('hasAuthOptions', 'canCreateLocal'),

  resetForm() {
    // We wrap the fields in a structure so we can assign a value
    this.setProperties({
      accountName: '',
      accountEmail: '',
      accountUsername: '',
      accountPassword: '',
      authOptions: null,
      complete: false,
      formSubmitted: false,
      rejectedEmails: [],
      rejectedPasswords: [],
      prefilledUsername: null,
      isDeveloper: false
    });
    this._createUserFields();
  },

  submitDisabled: function() {
    if (!this.get('emailValidation.failed') && !this.get('passwordRequired')) return false; // 3rd party auth
    if (this.get('formSubmitted')) return true;
    if (this.get('nameValidation.failed')) return true;
    if (this.get('emailValidation.failed')) return true;
    if (this.get('usernameValidation.failed')) return true;
    if (this.get('passwordValidation.failed')) return true;

    // Validate required fields
    let userFields = this.get('userFields');
    if (userFields) { userFields = userFields.filterBy('field.required'); }
    if (!Ember.isEmpty(userFields)) {
      const anyEmpty = userFields.any(function(uf) {
        const val = uf.get('value');
        return !val || Ember.isEmpty(val);
      });
      if (anyEmpty) { return true; }
    }
    return false;
  }.property('passwordRequired', 'nameValidation.failed', 'emailValidation.failed', 'usernameValidation.failed', 'passwordValidation.failed', 'formSubmitted', 'userFields.@each.value'),


  usernameRequired: Ember.computed.not('authOptions.omit_username'),

  fullnameRequired: function() {
    return this.get('siteSettings.full_name_required') || this.get('siteSettings.enable_names');
  }.property(),

  passwordRequired: function() {
    return Ember.isEmpty(this.get('authOptions.auth_provider'));
  }.property('authOptions.auth_provider'),

  disclaimerHtml: function() {
    return I18n.t('create_account.disclaimer', {
      tos_link: this.get('siteSettings.tos_url') || Discourse.getURL('/tos'),
      privacy_link: this.get('siteSettings.privacy_policy_url') || Discourse.getURL('/privacy')
    });
  }.property(),

  nameInstructions: function() {
    return I18n.t(Discourse.SiteSettings.full_name_required ? 'user.name.instructions_required' : 'user.name.instructions');
  }.property(),

  // Validate the name.
  nameValidation: function() {
    if (Discourse.SiteSettings.full_name_required && Ember.isEmpty(this.get('accountName'))) {
      return InputValidation.create({ failed: true });
    }

    return InputValidation.create({ok: true});
  }.property('accountName'),

  // Check the email address
  emailValidation: function() {
    // If blank, fail without a reason
    let email;
    if (Ember.isEmpty(this.get('accountEmail'))) {
      return InputValidation.create({
        failed: true
      });
    }

    email = this.get("accountEmail");

    if (this.get('rejectedEmails').includes(email)) {
      return InputValidation.create({
        failed: true,
        reason: I18n.t('user.email.invalid')
      });
    }

    if ((this.get('authOptions.email') === email) && this.get('authOptions.email_valid')) {
      return InputValidation.create({
        ok: true,
        reason: I18n.t('user.email.authenticated', {
          provider: this.authProviderDisplayName(this.get('authOptions.auth_provider'))
        })
      });
    }

    if (emailValid(email)) {
      return InputValidation.create({
        ok: true,
        reason: I18n.t('user.email.ok')
      });
    }

    return InputValidation.create({
      failed: true,
      reason: I18n.t('user.email.invalid')
    });
  }.property('accountEmail', 'rejectedEmails.[]'),

  emailValidated: function() {
    return this.get('authOptions.email') === this.get("accountEmail") && this.get('authOptions.email_valid');
  }.property('accountEmail', 'authOptions.email', 'authOptions.email_valid'),

  authProviderDisplayName(provider) {
    switch(provider) {
      case "Google_oauth2": return "Google";
      default: return provider;
    }
  },

  prefillUsername: function() {
    if (this.get('prefilledUsername')) {
      // If username field has been filled automatically, and email field just changed,
      // then remove the username.
      if (this.get('accountUsername') === this.get('prefilledUsername')) {
        this.set('accountUsername', '');
      }
      this.set('prefilledUsername', null);
    }
    if (this.get('emailValidation.ok') && (Ember.isEmpty(this.get('accountUsername')) || this.get('authOptions.email'))) {
      // If email is valid and username has not been entered yet,
      // or email and username were filled automatically by 3rd parth auth,
      // then look for a registered username that matches the email.
      this.fetchExistingUsername();
    }
  }.observes('emailValidation', 'accountEmail'),

  @on('init')
  fetchConfirmationValue() {
    return ajax('/users/hp.json').then(json => {
      this.set('accountPasswordConfirm', json.value);
      this.set('accountChallenge', json.challenge.split("").reverse().join(""));
    });
  },

  actions: {
    externalLogin(provider) {
      this.get('login').send('externalLogin', provider);
    },

    createAccount() {
      const self = this,
          attrs = this.getProperties('accountName', 'accountEmail', 'accountPassword', 'accountUsername', 'accountPasswordConfirm', 'accountChallenge'),
          userFields = this.get('userFields');

      // Add the userfields to the data
      if (!Ember.isEmpty(userFields)) {
        attrs.userFields = {};
        userFields.forEach(function(f) {
          attrs.userFields[f.get('field.id')] = f.get('value');
        });
      }

      this.set('formSubmitted', true);
      return Discourse.User.createAccount(attrs).then(function(result) {
        self.set('isDeveloper', false);
        if (result.success) {
          // Trigger the browser's password manager using the hidden static login form:
          const $hidden_login_form = $('#hidden-login-form');
          $hidden_login_form.find('input[name=username]').val(attrs.accountUsername);
          $hidden_login_form.find('input[name=password]').val(attrs.accountPassword);
          $hidden_login_form.find('input[name=redirect]').val(Discourse.getURL('/users/account-created'));
          $hidden_login_form.submit();
        } else {
          self.flash(result.message || I18n.t('create_account.failed'), 'error');
          if (result.is_developer) {
            self.set('isDeveloper', true);
          }
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

    let userFields = this.site.get('user_fields');
    if (userFields) {
      userFields = _.sortBy(userFields, 'position').map(function(f) {
        return Ember.Object.create({ value: null, field: f });
      });
    }
    this.set('userFields', userFields);
  }.on('init')

});
