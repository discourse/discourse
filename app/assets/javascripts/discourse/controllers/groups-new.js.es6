import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend({
  actions: {
    save() {
      this.set('disableSave', true);
      const group = this.get('model');

      group.create().then(() => {
        this.transitionToRoute("group.members", group.name);
      }).catch(popupAjaxError)
        .finally(() => this.set('disableSave', false));
    },
  }
});
