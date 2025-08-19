import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminEmailLogsRoute extends DiscourseRoute {
  titleToken() {
    return i18n("admin.config.email_logs.title");
  }

  setupController(controller) {
    controller.setProperties({
      loading: true,
      filter: { status: this.status },
    });
  }
}
