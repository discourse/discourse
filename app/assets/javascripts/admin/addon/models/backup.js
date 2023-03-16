import EmberObject from "@ember/object";
import MessageBus from "message-bus-client";
import { ajax } from "discourse/lib/ajax";

class Backup extends EmberObject {
  destroy() {
    return ajax("/admin/backups/" + this.filename, { type: "DELETE" });
  }

  restore() {
    return ajax("/admin/backups/" + this.filename + "/restore", {
      type: "POST",
      data: { client_id: MessageBus.clientId },
    });
  }
}

Backup.reopenClass({
  find() {
    return ajax("/admin/backups.json");
  },

  start(withUploads) {
    if (withUploads === undefined) {
      withUploads = true;
    }
    return ajax("/admin/backups", {
      type: "POST",
      data: {
        with_uploads: withUploads,
        client_id: MessageBus.clientId,
      },
    });
  },

  cancel() {
    return ajax("/admin/backups/cancel.json", {
      type: "DELETE",
    });
  },

  rollback() {
    return ajax("/admin/backups/rollback.json", {
      type: "POST",
    });
  },
});

export default Backup;
