import Controller from "@ember/controller";
import { exportEntity } from "discourse/lib/export-csv";
import { outputExportResult } from "discourse/lib/export-result";
import ScreenedUrl from "admin/models/screened-url";

export default Controller.extend({
  loading: false,

  show() {
    this.set("loading", true);
    ScreenedUrl.findAll().then(result => {
      this.set("model", result);
      this.set("loading", false);
    });
  },

  actions: {
    exportScreenedUrlList() {
      exportEntity("screened_url").then(outputExportResult);
    }
  }
});
