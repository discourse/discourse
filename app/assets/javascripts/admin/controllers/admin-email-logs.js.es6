import EmailLog from "admin/models/email-log";

export default Ember.Controller.extend({
  loading: false,

  loadLogs(sourceModel, loadMore) {
    if ((loadMore && this.get("loading")) || this.get("model.allLoaded")) {
      return;
    }

    this.set("loading", true);

    sourceModel = sourceModel || EmailLog;

    return sourceModel
      .findAll(this.get("filter"), loadMore ? this.get("model.length") : null)
      .then(logs => {
        if (this.get("model") && loadMore && logs.length < 50) {
          this.get("model").set("allLoaded", true);
        }

        if (this.get("model") && loadMore) {
          this.get("model").addObjects(logs);
        } else {
          this.set("model", logs);
        }
      })
      .finally(() => this.set("loading", false));
  },

  actions: {
    loadMore() {
      this.loadLogs(EmailLog, true);
    }
  }
});
