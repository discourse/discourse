import InputValidation from 'discourse/models/input-validation';
import debounce from 'discourse/lib/debounce';
import { setting } from 'discourse/lib/computed';

export default Ember.Mixin.create({

  uniqueUsernameValidation: null,
  globalNicknameExists: false, // TODO: remove this

  maxUsernameLength: setting('max_username_length'),
  minUsernameLength: setting('min_username_length'),

  fetchExistingUsername: debounce(function() {
    const self = this;
    Discourse.User.checkUsername(null, this.get('accountEmail')).then(function(result) {
      if (result.suggestion && (Ember.isEmpty(self.get('accountUsername')) || self.get('accountUsername') === self.get('authOptions.username'))) {
        self.set('accountUsername', result.suggestion);
        self.set('prefilledUsername', result.suggestion);
      }
    });
  }, 500),

  usernameMatch: function() {
    if (this.usernameNeedsToBeValidatedWithEmail()) {
      if (this.get('emailValidation.failed')) {
        if (this.shouldCheckUsernameMatch()) {
          return this.set('uniqueUsernameValidation', InputValidation.create({
            failed: true,
            reason: I18n.t('user.username.enter_email')
          }));
        } else {
          return this.set('uniqueUsernameValidation', InputValidation.create({ failed: true }));
        }
      } else if (this.shouldCheckUsernameMatch()) {
        this.set('uniqueUsernameValidation', InputValidation.create({
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
      return InputValidation.create({
        ok: true,
        reason: I18n.t('user.username.prefilled')
      });
    }

    // If blank, fail without a reason
    if (Ember.isEmpty(this.get('accountUsername'))) {
      return InputValidation.create({
        failed: true
      });
    }

    // If too short
    if (this.get('accountUsername').length < Discourse.SiteSettings.min_username_length) {
      return InputValidation.create({
        failed: true,
        reason: I18n.t('user.username.too_short')
      });
    }

    // If too long
    if (this.get('accountUsername').length > this.get('maxUsernameLength')) {
      return InputValidation.create({
        failed: true,
        reason: I18n.t('user.username.too_long')
      });
    }

    this.checkUsernameAvailability();
    // Let's check it out asynchronously
    return InputValidation.create({
      failed: true,
      reason: I18n.t('user.username.checking')
    });
  }.property('accountUsername'),

  shouldCheckUsernameMatch: function() {
    return !Ember.isEmpty(this.get('accountUsername')) && this.get('accountUsername').length >= this.get('minUsernameLength');
  },

  checkUsernameAvailability: debounce(function() {
    const _this = this;
    if (this.shouldCheckUsernameMatch()) {
      return Discourse.User.checkUsername(this.get('accountUsername'), this.get('accountEmail')).then(function(result) {
        _this.set('isDeveloper', false);
        if (result.available) {
          if (result.is_developer) {
            _this.set('isDeveloper', true);
          }
          return _this.set('uniqueUsernameValidation', InputValidation.create({
            ok: true,
            reason: I18n.t('user.username.available')
          }));
        } else {
          if (result.suggestion) {
            return _this.set('uniqueUsernameValidation', InputValidation.create({
              failed: true,
              reason: I18n.t('user.username.not_available', result)
            }));
          } else if (result.errors) {
            return _this.set('uniqueUsernameValidation', InputValidation.create({
              failed: true,
              reason: result.errors.join(' ')
            }));
          } else {
            return _this.set('uniqueUsernameValidation', InputValidation.create({
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
    const basicValidation = this.get('basicUsernameValidation');
    const uniqueUsername = this.get('uniqueUsernameValidation');
    return uniqueUsername ? uniqueUsername : basicValidation;
  }.property('uniqueUsernameValidation', 'basicUsernameValidation'),

  usernameNeedsToBeValidatedWithEmail() {
    return( this.get('globalNicknameExists') || false );
  }
});
