import { outputExportResult } from 'admin/lib/export-result';

export default Ember.ArrayController.extend(Discourse.Presence, {
  loading: false,

  actions: {
    clearBlock: function(row){
      row.clearBlock().then(function(){
        // feeling lazy
        window.location.reload();
      });
    },

    exportScreenedEmailList: function(subject) {
      Discourse.ExportCsv.exportScreenedEmailList().then(outputExportResult);
    }
  },

  show: function() {
    var self = this;
    self.set('loading', true);
    Discourse.ScreenedEmail.findAll().then(function(result) {
      self.set('model', result);
      self.set('loading', false);
    });
  }
});
