import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class LiveRoomsEditRoute extends DiscourseRoute {
  @service store;

  model(params) {
    return this.store.find("live-room", params.id);
  }
}
