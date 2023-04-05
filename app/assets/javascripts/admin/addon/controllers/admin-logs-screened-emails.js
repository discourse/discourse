import { action } from "@ember/object";
import Controller from "@ember/controller";
import ScreenedEmail from "admin/models/screened-email";
import { exportEntity } from "discourse/lib/export-csv";
import { outputExportResult } from "discourse/lib/export-result";

export default class AdminLogsScreenedEmailsController extends Controller {
  loading = false;

  @action
  clearBlock(row) {
    row.clearBlock().then(function () {
      // feeling lazy
      window.location.reload();
    });
  }

  @action
  exportScreenedEmailList() {
    exportEntity("screened_email").then(outputExportResult);
  }

  show() {
    this.set("loading", true);
    ScreenedEmail.findAll().then((result) => {
      this.set("model", result);
      this.set("loading", false);
    });
  }
}
