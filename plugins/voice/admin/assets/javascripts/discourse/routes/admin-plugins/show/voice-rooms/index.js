import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class VoiceRoomsIndexRoute extends DiscourseRoute {
  @service store;

  model() {
    return this.store.findAll("voice-room");
  }

  @action
  triggerRefresh() {
    this.refresh();
  }
}
