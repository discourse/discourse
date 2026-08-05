import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminDashboardTrafficRoute extends DiscourseRoute {
  @service currentUser;
  @service router;

  beforeModel() {
    if (!this.currentUser?.admin) {
      return this.router.replaceWith("/404");
    }
  }

  setupController(controller, model, transition) {
    super.setupController(...arguments);
    const { start_date: startDate, end_date: endDate } =
      transition.to.queryParams;

    if (moment(startDate, "YYYY-MM-DD", true).isValid()) {
      controller.start_date = startDate;
    }
    if (moment(endDate, "YYYY-MM-DD", true).isValid()) {
      controller.end_date = endDate;
    }

    controller.ensureDefaultRange();
  }

  titleToken() {
    return i18n("admin.dashboard.site_traffic.details.title");
  }
}
