import { exportEntity } from 'discourse/lib/export-csv';
import { outputExportResult } from 'discourse/lib/export-result';
import ScreenedEmail from 'admin/models/screened-email';

export default Ember.ArrayController.extend({
  loading: false,

  actions: {
    clearBlock(row){
      row.clearBlock().then(function(){
        // feeling lazy
        window.location.reload();
      });
    },

    exportScreenedEmailList() {
      exportEntity('screened_email').then(outputExportResult);
    }
  },

  show() {
    var self = this;
    self.set('loading', true);
    ScreenedEmail.findAll().then(function(result) {
      self.set('model', result);
      self.set('loading', false);
    });
  }
});
