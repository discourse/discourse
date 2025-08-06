import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseURL from "discourse/lib/url";
import DiscourseRoute from "discourse/routes/discourse";

export default class PostEventUpcomingEventsIndexRoute extends DiscourseRoute {
  @service discoursePostEventService;

  @action
  activate() {
    if (!this.siteSettings.discourse_post_event_enabled) {
      DiscourseURL.redirectTo("/404");
    }
  }

  async model(params) {
    return await this.discoursePostEventService.fetchEvents(params);
  }
}
