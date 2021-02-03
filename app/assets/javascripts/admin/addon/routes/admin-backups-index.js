import Backup from "admin/models/backup";
import Route from "@ember/routing/route";

export default Route.extend({
  activate() {
    this.messageBus.subscribe("/admin/backups", (backups) =>
      this.controller.set(
        "model",
        backups.map((backup) => Backup.create(backup))
      )
    );
  },

  model() {
    return Backup.find().then((backups) =>
      backups.map((backup) => Backup.create(backup))
    );
  },

  deactivate() {
    this.messageBus.unsubscribe("/admin/backups");
  },
});
