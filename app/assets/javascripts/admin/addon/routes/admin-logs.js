import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminLogsRoute extends DiscourseRoute {
  titleToken() {
    return i18n("admin.config.staff_action_logs.title");
  }
}
