import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export default class VoiceRoomsNewController extends Controller {
  @service router;
  @service toasts;

  @action
  saveRoom() {
    this.toasts.success({
      data: { message: i18n("voice.admin.room_created") },
      duration: 2000,
    });
    this.router.transitionTo("adminPlugins.show.voice-rooms.index");
  }
}
