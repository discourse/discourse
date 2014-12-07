import { outputExportResult } from 'admin/lib/export-result';

export default Ember.ArrayController.extend(Discourse.Presence, {
  loading: false,

  show: function() {
    var self = this;
    self.set('loading', true);
    Discourse.ScreenedUrl.findAll().then(function(result) {
      self.set('model', result);
      self.set('loading', false);
    });
  },

  actions: {
    exportScreenedUrlList: function(subject) {
      Discourse.ExportCsv.exportScreenedUrlList().then(outputExportResult);
    }
  }
});
