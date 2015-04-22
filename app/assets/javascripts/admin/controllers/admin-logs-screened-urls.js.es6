import Presence from 'discourse/mixins/presence';
import { outputExportResult } from 'discourse/lib/export-result';

export default Ember.ArrayController.extend(Presence, {
  loading: false,

  show() {
    const self = this;
    self.set('loading', true);
    Discourse.ScreenedUrl.findAll().then(function(result) {
      self.set('model', result);
      self.set('loading', false);
    });
  },

  actions: {
    exportScreenedUrlList() {
      Discourse.ExportCsv.exportScreenedUrlList().then(outputExportResult);
    }
  }
});
