import DiscourseRoute from "discourse/routes/discourse";

export default class AdminEmailLogsRoute extends DiscourseRoute {
  setupController(controller) {
    controller.setProperties({
      loading: true,
      filter: { status: this.status },
    });
  }
}
