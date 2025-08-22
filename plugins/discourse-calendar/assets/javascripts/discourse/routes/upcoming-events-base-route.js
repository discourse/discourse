import { service } from "@ember/service";
import moment from "moment";
import DiscourseURL from "discourse/lib/url";
import DiscourseRoute from "discourse/routes/discourse";

export default class UpcomingEventsBaseRoute extends DiscourseRoute {
  @service discoursePostEventService;
  @service currentUser;

  activate() {
    if (!this.siteSettings.discourse_post_event_enabled) {
      DiscourseURL.redirectTo("/404");
    }
  }

  async model(params) {
    let after, before, initialDate;

    if (params.view === "year") {
      const year = parseInt(params.year, 10);
      after = moment.utc({ year }).startOf("year").toISOString();
      before = moment.utc({ year }).endOf("year").toISOString();
      initialDate = moment.utc({ year }).format("YYYY-MM-DD");
    } else if (params.view === "month") {
      const year = parseInt(params.year, 10);
      const month = parseInt(params.month, 10) - 1; // moment months are 0-indexed

      const date = moment.utc({ year, month });
      after = date.clone().startOf("month").toISOString();
      before = date.clone().endOf("month").toISOString();
      initialDate = moment.utc({ year, month }).format("YYYY-MM-DD");
    } else if (params.view === "week") {
      const year = parseInt(params.year, 10);
      const month = parseInt(params.month, 10) - 1; // moment months are 0-indexed
      const day = parseInt(params.day, 10);

      const date = moment.utc({ year, month, day });
      after = date.clone().startOf("week").toISOString();
      before = date.clone().endOf("week").toISOString();
      initialDate = moment.utc({ year, month, day }).format("YYYY-MM-DD");
    } else if (params.view === "day") {
      const year = parseInt(params.year, 10);
      const month = parseInt(params.month, 10) - 1; // moment months are 0-indexed
      const day = parseInt(params.day, 10);

      const date = moment.utc({ year, month, day });
      after = date.clone().startOf("day").toISOString();
      before = date.clone().endOf("day").toISOString();
      initialDate = moment.utc({ year, month, day }).format("YYYY-MM-DD");
    }

    const fetchParams = {
      after,
      before,
    };

    this.addRouteSpecificParams(fetchParams);

    const events =
      await this.discoursePostEventService.fetchEvents(fetchParams);

    return {
      events,
      initialDate,
      view: params.view,
    };
  }

  // Override in subclasses to add route-specific parameters
  addRouteSpecificParams() {}
}
