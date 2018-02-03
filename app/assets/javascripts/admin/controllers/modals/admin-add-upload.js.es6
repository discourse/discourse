import ModalFunctionality from 'discourse/mixins/modal-functionality';
import { ajax } from 'discourse/lib/ajax';
import { default as computed, observes } from 'ember-addons/ember-computed-decorators';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend(ModalFunctionality, {
  adminCustomizeThemesShow: Ember.inject.controller(),

  onShow() {
    this.set('name', null);
    this.set('fileSelected', false);
  },

  enabled: Em.computed.and('nameValid', 'fileSelected'),
  disabled: Em.computed.not('enabled'),

  @computed('name')
  nameValid(name) {
    return name && name.match(/^[a-z_][a-z0-9_-]*$/i);
  },

  @observes('name')
  uploadChanged() {
    const file = $('#file-input')[0];
    this.set('fileSelected', file && file.files[0]);
  },

  actions: {

    updateName() {
      let name = this.get('name');
      if (Em.isEmpty(name)) {
        name = $('#file-input')[0].files[0].name;
        this.set('name', name.split(".")[0]);
      }
      this.uploadChanged();
    },

    upload() {
      const file = $('#file-input')[0].files[0];

      const options = {
        type: 'POST',
        processData: false,
        contentType: false,
        data: new FormData()
      };

      options.data.append('file', file);

      ajax('/admin/themes/upload_asset', options).then(result => {
        const upload = {
          upload_id: result.upload_id,
          name: this.get('name'),
          original_filename: file.name
        };
        this.get('adminCustomizeThemesShow').send('addUpload', upload);
        this.send('closeModal');
      }).catch(e => {
        popupAjaxError(e);
      });
    }
  }
});
