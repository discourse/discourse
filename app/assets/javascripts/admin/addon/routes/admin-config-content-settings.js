import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminConfigContentSettingsRoute extends DiscourseRoute {
  @service router;

  beforeModel(transition) {
    let { queryParams } = transition.to;

    if (transition.to.name !== "adminConfig.content") {
      this.router.replaceWith("adminConfig.content", { queryParams });
    }
  }
}
