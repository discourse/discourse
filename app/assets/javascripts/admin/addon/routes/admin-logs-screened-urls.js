import DiscourseRoute from "discourse/routes/discourse";

export default class AdminLogsScreenedUrlsRoute extends DiscourseRoute {
  setupController() {
    return this.controllerFor("adminLogsScreenedUrls").show();
  }
}
