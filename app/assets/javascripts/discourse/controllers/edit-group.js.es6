import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend({
  saving: false,

  actions: {
    save() {
      this.set('saving', true);

      this.get('model').save().then(() => {
        this.transitionToRoute('group', this.get('model.name'));
        this.send('closeModal');
      }).catch(error => {
        popupAjaxError(error);
      }).finally(() => {
        this.set('saving', false);
      });
    }
  }
});
