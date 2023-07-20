import Backup from "admin/models/backup";
import Route from "@ember/routing/route";
import { bind } from "discourse-common/utils/decorators";

export default class AdminBackupsIndexRoute extends Route {
  activate() {
    this.messageBus.subscribe("/admin/backups", this.onMessage);
  }

  deactivate() {
    this.messageBus.unsubscribe("/admin/backups", this.onMessage);
  }

  model() {
    return Backup.find().then((backups) =>
      backups.map((backup) => Backup.create(backup))
    );
  }

  @bind
  onMessage(backups) {
    this.controller.set(
      "model",
      backups.map((backup) => Backup.create(backup))
    );
  }
}
