import InputValidation from 'discourse/models/input-validation';
import { default as computed } from 'ember-addons/ember-computed-decorators';

export default Ember.Mixin.create({

  rejectedPasswords: null,

  init() {
    this._super();
    this.set('rejectedPasswords', []);
    this.set('rejectedPasswordsMessages', Ember.Map.create());
  },

  @computed('passwordMinLength')
  passwordInstructions() {
    return I18n.t('user.password.instructions', {count: this.get('passwordMinLength')});
  },

  @computed('isDeveloper')
  passwordMinLength() {
    return this.get('isDeveloper') ? this.siteSettings.min_admin_password_length : this.siteSettings.min_password_length;
  },

  @computed('accountPassword', 'passwordRequired', 'rejectedPasswords.[]', 'accountUsername', 'accountEmail', 'isDeveloper')
  passwordValidation(password, passwordRequired, rejectedPasswords, accountUsername, accountEmail, isDeveloper) {
    if (!passwordRequired) {
      return InputValidation.create({ ok: true });
    }

    if (rejectedPasswords.includes(password)) {
      return InputValidation.create({
        failed: true,
        reason: this.get('rejectedPasswordsMessages').get(password) || I18n.t('user.password.common')
      });
    }

    // If blank, fail without a reason
    if (Ember.isEmpty(password)) {
      return InputValidation.create({ failed: true });
    }

    // If too short
    const passwordLength = isDeveloper ? this.siteSettings.min_admin_password_length : this.siteSettings.min_password_length;
    if (password.length < passwordLength) {
      return InputValidation.create({
        failed: true,
        reason: I18n.t('user.password.too_short')
      });
    }

    if (!Ember.isEmpty(accountUsername) && password === accountUsername) {
      return InputValidation.create({
        failed: true,
        reason: I18n.t('user.password.same_as_username')
      });
    }

    if (!Ember.isEmpty(accountEmail) && password === accountEmail) {
      return InputValidation.create({
        failed: true,
        reason: I18n.t('user.password.same_as_email')
      });
    }

    // Looks good!
    return InputValidation.create({
      ok: true,
      reason: I18n.t('user.password.ok')
    });
  }
});
