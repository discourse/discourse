import { default as computed, on } from 'ember-addons/ember-computed-decorators';
import InputValidation from 'discourse/models/input-validation';

export default Ember.Component.extend({
  classNames: ['title-input'],

  @on('didInsertElement')
  _focusOnTitle() {
    if (!this.capabilities.isIOS) {
      this.$('input').putCursorAtEnd();
    }
  },

  @computed('composer.titleLength', 'composer.missingTitleCharacters', 'composer.minimumTitleLength', 'lastValidatedAt')
  validation(titleLength, missingTitleChars, minimumTitleLength, lastValidatedAt) {

    let reason;
    if (titleLength < 1) {
      reason = I18n.t('composer.error.title_missing');
    } else if (missingTitleChars > 0) {
      reason = I18n.t('composer.error.title_too_short', {min: minimumTitleLength});
    } else if (titleLength > this.siteSettings.max_topic_title_length) {
      reason = I18n.t('composer.error.title_too_long', {max: this.siteSettings.max_topic_title_length});
    }

    if (reason) {
      return InputValidation.create({ failed: true, reason, lastShownAt: lastValidatedAt });
    }
  }
});
