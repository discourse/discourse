import UpcomingEventsBaseRoute from "./upcoming-events-base-route";

export default class PostEventUpcomingEventsMineRoute extends UpcomingEventsBaseRoute {
  addRouteSpecificParams(fetchParams) {
    fetchParams.attending_user = this.currentUser?.username;
  }
}
