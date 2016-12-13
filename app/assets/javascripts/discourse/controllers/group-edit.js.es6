import { popupAjaxError } from 'discourse/lib/ajax-error';
import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({
  @computed('saving')
  savingText(saving) {
    if (saving !== undefined) {
      return saving ? I18n.t('saving') : I18n.t('saved');
    }
  },

  actions: {
    save() {
      this.set('saving', true);

      this.get('model').save().catch(error => {
        popupAjaxError(error);
      }).finally(() => {
        this.set('saving', false);
      });
    }
  }
});
