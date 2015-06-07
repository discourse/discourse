import Presence from 'discourse/mixins/presence';
import { outputExportResult } from 'discourse/lib/export-result';

export default Ember.ArrayController.extend(Presence, {
  loading: false,

  actions: {
    clearBlock(row){
      row.clearBlock().then(function(){
        // feeling lazy
        window.location.reload();
      });
    },

    exportScreenedEmailList() {
      Discourse.ExportCsv.exportScreenedEmailList().then(outputExportResult);
    }
  },

  show() {
    var self = this;
    self.set('loading', true);
    Discourse.ScreenedEmail.findAll().then(function(result) {
      self.set('model', result);
      self.set('loading', false);
    });
  }
});
