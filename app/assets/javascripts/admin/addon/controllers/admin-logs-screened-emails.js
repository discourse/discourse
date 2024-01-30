import Controller from "@ember/controller";
import { action } from "@ember/object";
import { exportEntity } from "discourse/lib/export-csv";
import { outputExportResult } from "discourse/lib/export-result";
import ScreenedEmail from "admin/models/screened-email";

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
