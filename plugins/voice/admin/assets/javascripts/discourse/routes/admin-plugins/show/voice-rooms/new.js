import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class VoiceRoomsNewRoute extends DiscourseRoute {
  @service store;

  model() {
    return this.store.createRecord("voice-room");
  }
}
