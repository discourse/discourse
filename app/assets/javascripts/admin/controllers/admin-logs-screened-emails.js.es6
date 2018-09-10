import { exportEntity } from "discourse/lib/export-csv";
import { outputExportResult } from "discourse/lib/export-result";
import ScreenedEmail from "admin/models/screened-email";

export default Ember.Controller.extend({
  loading: false,

  actions: {
    clearBlock(row) {
      row.clearBlock().then(function() {
        // feeling lazy
        window.location.reload();
      });
    },

    exportScreenedEmailList() {
      exportEntity("screened_email").then(outputExportResult);
    }
  },

  show() {
    this.set("loading", true);
    ScreenedEmail.findAll().then(result => {
      this.set("model", result);
      this.set("loading", false);
    });
  }
});
