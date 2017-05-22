import PreferencesTabController from "discourse/mixins/preferences-tab-controller";
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend(PreferencesTabController, {
  saveAttrNames: [
    'muted_category_ids',
    'watched_category_ids',
    'tracked_category_ids',
    'watched_first_post_category_ids'
  ],

  actions: {
    save() {
      this.set('saved', false);
      return this.get('model').save(this.get('saveAttrNames')).then(() => {
        this.set('saved', true);
      }).catch(popupAjaxError);
    }
  }
});
