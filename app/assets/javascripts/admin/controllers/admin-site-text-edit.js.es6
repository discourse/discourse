import { popupAjaxError } from 'discourse/lib/ajax-error';
import { bufferedProperty } from 'discourse/mixins/buffered-content';

export default Ember.Controller.extend(bufferedProperty('siteText'), {
  saved: false,

  actions: {
    saveChanges() {
      const buffered = this.get('buffered');
      this.get('siteText').save(buffered.getProperties('value')).then(() => {
        this.commitBuffer();
        this.set('saved', true);
      }).catch(popupAjaxError);
    },

    revertChanges() {
      this.set('saved', false);
      bootbox.confirm(I18n.t('admin.site_text.revert_confirm'), result => {
        if (result) {
          this.get('siteText').revert().then(props => {
            const buffered = this.get('buffered');
            buffered.setProperties(props);
            this.commitBuffer();
          }).catch(popupAjaxError);
        }
      });
    }
  }
});
