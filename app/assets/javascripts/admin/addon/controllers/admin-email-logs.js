import Controller from "@ember/controller";
import EmailLog from "admin/models/email-log";
import EmberObject, { action } from "@ember/object";

export default class AdminEmailLogsController extends Controller {
  loading = false;
  filter = EmberObject.create();

  loadLogs(sourceModel, loadMore) {
    if ((loadMore && this.loading) || this.get("model.allLoaded")) {
      return;
    }

    this.set("loading", true);

    sourceModel = sourceModel || EmailLog;

    let args = {};
    Object.keys(this.filter).forEach((k) => {
      if (this.filter[k]) {
        args[k] = this.filter[k];
      }
    });
    return sourceModel
      .findAll(args, loadMore ? this.get("model.length") : null)
      .then((logs) => {
        if (this.model && loadMore && logs.length < 50) {
          this.model.set("allLoaded", true);
        }

        if (this.model && loadMore) {
          this.model.addObjects(logs);
        } else {
          this.set("model", logs);
        }
      })
      .finally(() => this.set("loading", false));
  }

  @action
  loadMore() {
    this.loadLogs(EmailLog, true);
  }
}
