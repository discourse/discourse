import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseURL from "discourse/lib/url";
import DiscourseRoute from "discourse/routes/discourse";

export default class PostEventUpcomingEventsIndexRoute extends DiscourseRoute {
  @service discoursePostEventApi;
  @service discoursePostEventService;
  @service currentUser;

  @action
  activate() {
    if (!this.siteSettings.discourse_post_event_enabled) {
      DiscourseURL.redirectTo("/404");
    }
  }

  async model(params) {
    params.attending_user = this.currentUser?.username;
    return await this.discoursePostEventService.fetchEvents(params);
  }
}
