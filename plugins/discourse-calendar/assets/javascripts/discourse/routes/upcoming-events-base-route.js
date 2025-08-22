import { service } from "@ember/service";
import DiscourseURL from "discourse/lib/url";
import DiscourseRoute from "discourse/routes/discourse";
import moment from "moment";

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

    // Get user's timezone for initialDate (FullCalendar expects dates in user timezone)
    const userTimezone =
      this.currentUser?.user_option?.timezone || moment.tz.guess();

    if (params.view === "year") {
      const year = parseInt(params.year, 10);
      after = moment.utc({ year }).startOf("year").toISOString();
      before = moment.utc({ year }).endOf("year").toISOString();
      initialDate = moment.tz({ year }, userTimezone).toISOString();
    } else if (params.view === "month") {
      const year = parseInt(params.year, 10);
      const month = parseInt(params.month, 10) - 1; // moment months are 0-indexed

      const date = moment.utc({ year, month });
      after = date.clone().startOf("month").toISOString();
      before = date.clone().endOf("month").toISOString();
      initialDate = moment.tz({ year, month }, userTimezone).toISOString();
    } else if (params.view === "week") {
      const year = parseInt(params.year, 10);
      const month = parseInt(params.month, 10) - 1; // moment months are 0-indexed
      const day = parseInt(params.day, 10);

      const date = moment.utc({ year, month, day });
      after = date.clone().startOf("week").toISOString();
      before = date.clone().endOf("week").toISOString();
      initialDate = moment.tz({ year, month, day }, userTimezone).toISOString();
    } else if (params.view === "day") {
      const year = parseInt(params.year, 10);
      const month = parseInt(params.month, 10) - 1; // moment months are 0-indexed
      const day = parseInt(params.day, 10);

      const date = moment.utc({ year, month, day });
      after = date.clone().startOf("day").toISOString();
      before = date.clone().endOf("day").toISOString();
      initialDate = moment.tz({ year, month, day }, userTimezone).toISOString();
    } else {
      // Fallback for query params (backward compatibility)
      after = params.start;
      before = params.end;
    }

    const fetchParams = {
      after,
      before,
    };

    // Add attending_user for mine route - subclasses can override this
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
  addRouteSpecificParams(fetchParams) {
    // Base implementation does nothing
  }
}
