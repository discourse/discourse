import { service } from "@ember/service";
import moment from "moment";
import DiscourseRoute from "discourse/routes/discourse";

export default class PostEventUpcomingEventsDefaultIndexRoute extends DiscourseRoute {
  @service currentUser;
  @service router;
  @service siteSettings;

  beforeModel() {
    // Use the user's TZ so the redirect date matches what the calendar will render.
    const tz = this.currentUser?.user_option?.timezone;
    const today = tz ? moment.tz(tz) : moment();
    const year = today.year();
    const month = today.month() + 1; // moment months are 0-indexed, but URLs use 1-indexed
    const day = today.date();

    this.router?.replaceWith?.(
      "discourse-post-event-upcoming-events.index",
      this.siteSettings.calendar_upcoming_events_default_view,
      year,
      month,
      day
    );
  }
}
