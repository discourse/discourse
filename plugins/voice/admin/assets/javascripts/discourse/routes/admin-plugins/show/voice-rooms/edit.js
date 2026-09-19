import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class VoiceRoomsEditRoute extends DiscourseRoute {
  @service store;

  model(params) {
    return this.store.find("voice-room", params.id);
  }
}
