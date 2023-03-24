import EmberObject from "@ember/object";
import MessageBus from "message-bus-client";
import { ajax } from "discourse/lib/ajax";

export default class Backup extends EmberObject {
  static find() {
    return ajax("/admin/backups.json");
  }

  static start(withUploads) {
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
  }

  static cancel() {
    return ajax("/admin/backups/cancel.json", {
      type: "DELETE",
    });
  }

  static rollback() {
    return ajax("/admin/backups/rollback.json", {
      type: "POST",
    });
  }

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
