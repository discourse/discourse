import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import EmailLog from "admin/models/email-log";

export default class AdminEmailLogsController extends Controller {
  @tracked loading = false;
  @tracked status = "";

  filters = []; // populated by child controllers

  loadLogs(sourceModel, loadMore) {
    if (
      (loadMore && this.loading) ||
      (loadMore && this.get("model.allLoaded"))
    ) {
      return;
    }

    this.set("loading", true);

    if (!loadMore && this.model) {
      this.model.set("allLoaded", false);
    }

    sourceModel = sourceModel || EmailLog;

    let filterArgs = this.getFilterArgs();
    return sourceModel
      .findAll(filterArgs, loadMore ? this.get("model.length") : null)
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

  getFilterArgs() {
    const args = { status: this.status };

    this.filters.forEach(({ property, name }) => {
      const value = this[property];
      if (value) {
        args[name] = value;
      }
    });

    return args;
  }

  @action
  loadMore() {
    this.loadLogs(EmailLog, true);
  }
}
