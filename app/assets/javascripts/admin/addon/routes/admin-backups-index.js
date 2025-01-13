import Route from "@ember/routing/route";
import { bind } from "discourse/lib/decorators";
import Backup from "admin/models/backup";

export default class AdminBackupsIndexRoute extends Route {
  activate() {
    this.messageBus.subscribe("/admin/backups", this.onMessage);
  }

  deactivate() {
    this.messageBus.unsubscribe("/admin/backups", this.onMessage);
  }

  async model() {
    const backups = await Backup.find();
    return backups.map((backup) => Backup.create(backup));
  }

  @bind
  onMessage(backups) {
    this.controller.set(
      "model",
      backups.map((backup) => Backup.create(backup))
    );
  }
}
