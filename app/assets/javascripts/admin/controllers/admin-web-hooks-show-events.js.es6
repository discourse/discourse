import { ajax } from 'discourse/lib/ajax';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend({
  actions: {
    loadMore() {
      this.get('model').loadMore();
    },

    ping() {
      ajax(`/admin/web_hooks/${this.get('model.extras.web_hook_id')}/ping`, {type: 'POST'}).catch(popupAjaxError);
    }
  }
});
