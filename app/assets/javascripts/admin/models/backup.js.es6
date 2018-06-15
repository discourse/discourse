import { ajax } from "discourse/lib/ajax";
import PreloadStore from "preload-store";

const Backup = Discourse.Model.extend({
  destroy() {
    return ajax("/admin/backups/" + this.get("filename"), { type: "DELETE" });
  },

  restore() {
    return ajax("/admin/backups/" + this.get("filename") + "/restore", {
      type: "POST",
      data: { client_id: window.MessageBus.clientId }
    });
  }
});

Backup.reopenClass({
  find() {
    return PreloadStore.getAndRemove("backups", () =>
      ajax("/admin/backups.json")
    ).then(backups => backups.map(backup => Backup.create(backup)));
  },

  start(withUploads) {
    if (withUploads === undefined) {
      withUploads = true;
    }
    return ajax("/admin/backups", {
      type: "POST",
      data: {
        with_uploads: withUploads,
        client_id: window.MessageBus.clientId
      }
    }).then(result => {
      if (!result.success) {
        bootbox.alert(result.message);
      }
    });
  },

  cancel() {
    return ajax("/admin/backups/cancel.json", {
      type: "DELETE"
    }).then(result => {
      if (!result.success) {
        bootbox.alert(result.message);
      }
    });
  },

  rollback() {
    return ajax("/admin/backups/rollback.json", {
      type: "POST"
    }).then(result => {
      if (!result.success) {
        bootbox.alert(result.message);
      } else {
        // redirect to homepage (session might be lost)
        window.location.pathname = Discourse.getURL("/");
      }
    });
  }
});

export default Backup;
