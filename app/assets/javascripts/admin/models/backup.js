import getURL from "discourse-common/lib/get-url";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import EmberObject from "@ember/object";
import MessageBus from "message-bus-client";

const Backup = EmberObject.extend({
  destroy() {
    return ajax("/admin/backups/" + this.filename, { type: "DELETE" });
  },

  restore() {
    return ajax("/admin/backups/" + this.filename + "/restore", {
      type: "POST",
      data: { client_id: MessageBus.clientId }
    });
  }
});

Backup.reopenClass({
  find() {
    return ajax("/admin/backups.json")
      .then(backups => backups.map(backup => Backup.create(backup)))
      .catch(error => {
        bootbox.alert(
          I18n.t("admin.backups.backup_storage_error", {
            error_message: extractError(error)
          })
        );
        return [];
      });
  },

  start(withUploads) {
    if (withUploads === undefined) {
      withUploads = true;
    }
    return ajax("/admin/backups", {
      type: "POST",
      data: {
        with_uploads: withUploads,
        client_id: MessageBus.clientId
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
        window.location = getURL("/");
      }
    });
  }
});

export default Backup;
