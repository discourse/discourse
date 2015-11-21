import { exportEntity } from 'discourse/lib/export-csv';
import { outputExportResult } from 'discourse/lib/export-result';
import ScreenedUrl from 'admin/models/screened-url';

export default Ember.ArrayController.extend({
  loading: false,

  show() {
    const self = this;
    self.set('loading', true);
    ScreenedUrl.findAll().then(function(result) {
      self.set('model', result);
      self.set('loading', false);
    });
  },

  actions: {
    exportScreenedUrlList() {
      exportEntity('screened_url').then(outputExportResult);
    }
  }
});
