import Route from "@ember/routing/route";
import Backup from "admin/models/backup";

export default Route.extend({
  activate() {
    this.messageBus.subscribe("/admin/backups", backups =>
      this.controller.set(
        "model",
        backups.map(backup => Backup.create(backup))
      )
    );
  },

  model() {
    return Backup.find();
  },

  deactivate() {
    this.messageBus.unsubscribe("/admin/backups");
  }
});
