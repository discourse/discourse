import DiscourseRoute from "discourse/routes/discourse";

export default class AdminLogsScreenedEmailsRoute extends DiscourseRoute {
  setupController() {
    return this.controllerFor("adminLogsScreenedEmails").show();
  }
}
