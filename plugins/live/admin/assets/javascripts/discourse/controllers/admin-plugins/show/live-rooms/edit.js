import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export default class LiveRoomsEditController extends Controller {
  @service router;
  @service toasts;

  @action
  saveRoom() {
    this.toasts.success({
      data: { message: i18n("live.admin.room_updated") },
      duration: "short",
    });
    this.router.transitionTo("adminPlugins.show.live-rooms.index");
  }
}
