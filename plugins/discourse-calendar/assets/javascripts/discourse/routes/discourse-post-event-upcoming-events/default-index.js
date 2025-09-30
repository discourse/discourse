import { service } from "@ember/service";
import moment from "moment";
import DiscourseRoute from "discourse/routes/discourse";

export default class PostEventUpcomingEventsDefaultIndexRoute extends DiscourseRoute {
  @service router;

  beforeModel() {
    const today = moment();
    const year = today.year();
    const month = today.month() + 1; // moment months are 0-indexed, but URLs use 1-indexed
    const day = today.date();

    this.router?.replaceWith?.(
      "discourse-post-event-upcoming-events.index",
      "month",
      year,
      month,
      day
    );
  }
}
