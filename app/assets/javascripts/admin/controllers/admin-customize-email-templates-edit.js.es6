import { popupAjaxError } from 'discourse/lib/ajax-error';
import { bufferedProperty } from 'discourse/mixins/buffered-content';

export default Ember.Controller.extend(bufferedProperty('emailTemplate'), {
  saved: false,

  actions: {
    saveChanges() {
      const model = this.get('emailTemplate');
      const buffered = this.get('buffered');
      model.save(buffered.getProperties('subject', 'body')).then(() => {
        this.set('saved', true);
      }).catch(popupAjaxError);
    }
  }
});
