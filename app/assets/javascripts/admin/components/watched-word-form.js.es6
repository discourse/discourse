import WatchedWord from 'admin/models/watched-word';
import { default as computed, on, observes } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  classNames: ['watched-word-form'],
  formSubmitted: false,
  actionKey: null,
  showSuccessMessage: false,

  @computed('regularExpressions')
  placeholderKey(regularExpressions) {
    return "admin.watched_words.form.placeholder" +
      (regularExpressions ? "_regexp" : "");
  },

  @observes('word')
  removeSuccessMessage() {
    if (this.get('showSuccessMessage') && !Ember.isEmpty(this.get('word'))) {
      this.set('showSuccessMessage', false);
    }
  },

  actions: {
    submit() {
      if (!this.get('formSubmitted')) {
        this.set('formSubmitted', true);

        const watchedWord = WatchedWord.create({ word: this.get('word'), action: this.get('actionKey') });

        watchedWord.save().then(result => {
          this.setProperties({ word: '', formSubmitted: false, showSuccessMessage: true });
          this.sendAction('action', WatchedWord.create(result));
          Ember.run.schedule('afterRender', () => this.$('.watched-word-input').focus());
        }).catch(e => {
          this.set('formSubmitted', false);
          const msg = (e.responseJSON && e.responseJSON.errors) ?
                      I18n.t("generic_error_with_reason", {error: e.responseJSON.errors.join('. ')}) :
                      I18n.t("generic_error");
          bootbox.alert(msg, () => this.$('.watched-word-input').focus());
        });
      }
    }
  },

  @on("didInsertElement")
  _init() {
    Ember.run.schedule('afterRender', () => {
      this.$('.watched-word-input').keydown(e => {
        if (e.keyCode === 13) {
          this.send('submit');
        }
      });
    });
  }
});
