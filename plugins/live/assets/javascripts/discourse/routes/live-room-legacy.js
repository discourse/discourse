import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class LiveRoomLegacyRoute extends DiscourseRoute {
  @service router;

  model(params, transition) {
    this.router.replaceWith("live-room", params.slug, {
      queryParams: transition.to.queryParams,
    });
  }
}
