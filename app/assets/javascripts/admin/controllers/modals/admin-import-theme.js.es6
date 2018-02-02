import ModalFunctionality from 'discourse/mixins/modal-functionality';
import { ajax } from 'discourse/lib/ajax';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend(ModalFunctionality, {
  local: Ember.computed.equal('selection', 'local'),
  remote: Ember.computed.equal('selection', 'remote'),
  selection: 'local',
  adminCustomizeThemes: Ember.inject.controller(),
  loading: false,

  actions: {
    importTheme() {

      let options = {
        type: 'POST'
      };

      if (this.get('local')) {
        options.processData = false;
        options.contentType = false;
        options.data = new FormData();
        options.data.append('theme', $('#file-input')[0].files[0]);
      } else {
        options.data = {remote: this.get('uploadUrl')};
      }

      this.set('loading', true);
      ajax('/admin/themes/import', options).then(result=>{
        const theme = this.store.createRecord('theme',result.theme);
        this.get('adminCustomizeThemes').send('addTheme', theme);
        this.send('closeModal');
      }).catch(popupAjaxError).finally(() => this.set('loading', false));

    }
  }
});
