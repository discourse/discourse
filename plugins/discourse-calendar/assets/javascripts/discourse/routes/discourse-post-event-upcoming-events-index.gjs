import { service } from "@ember/service";
import DiscourseURL from "discourse/lib/url";
import DiscourseRoute from "discourse/routes/discourse";

export default class PostEventUpcomingEventsIndexRoute extends DiscourseRoute {
  @service discoursePostEventService;

  queryParams = {
    start: { refreshModel: true },
    end: { refreshModel: true },
    view: { refreshModel: true },
  };

  async model(params) {
    return await this.discoursePostEventService.fetchEvents({
      after: params.start,
      before: params.end,
    });
  }

  activate() {
    if (!this.siteSettings.discourse_post_event_enabled) {
      DiscourseURL.redirectTo("/404");
    }
  }
}
