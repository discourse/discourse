import InputValidation from 'discourse/models/input-validation';
import { default as computed, on } from 'ember-addons/ember-computed-decorators';

export default Ember.Mixin.create({

  rejectedPasswords: Em.A([]),

  @on('init')
  _initRejectedPassword() {
    this.set('rejectedPasswordsMessages', Ember.Map.create());
  },

  @computed('isDeveloper')
  passwordInstructions: function() {
    return I18n.t('user.password.instructions', {count: this.get('passwordMinLength')});
  },

  @computed('isDeveloper')
  passwordMinLength() {
    return this.get('isDeveloper') ? Discourse.SiteSettings.min_admin_password_length : Discourse.SiteSettings.min_password_length;
  },

  @computed('accountPassword', 'rejectedPasswords.[]', 'accountUsername', 'accountEmail', 'isDeveloper')
  passwordValidation() {
    if (!this.get('passwordRequired')) {
      return InputValidation.create({ ok: true });
    }

    const password = this.get("accountPassword");

    if (this.get('rejectedPasswords').includes(password)) {
      return InputValidation.create({
        failed: true,
        reason: this.get('rejectedPasswordsMessages').get(password) || I18n.t('user.password.common')
      });
    }

    // If blank, fail without a reason
    if (Ember.isEmpty(this.get('accountPassword'))) {
      return InputValidation.create({ failed: true });
    }

    // If too short
    const passwordLength = this.get('isDeveloper') ? Discourse.SiteSettings.min_admin_password_length : Discourse.SiteSettings.min_password_length;
    if (password.length < passwordLength) {
      return InputValidation.create({
        failed: true,
        reason: I18n.t('user.password.too_short')
      });
    }

    if (!Ember.isEmpty(this.get('accountUsername')) && this.get('accountPassword') === this.get('accountUsername')) {
      return InputValidation.create({
        failed: true,
        reason: I18n.t('user.password.same_as_username')
      });
    }

    if (!Ember.isEmpty(this.get('accountEmail')) && this.get('accountPassword') === this.get('accountEmail')) {
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
