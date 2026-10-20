import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class LiveRoomsNewRoute extends DiscourseRoute {
  @service store;

  model() {
    return this.store.createRecord("live-room");
  }
}
