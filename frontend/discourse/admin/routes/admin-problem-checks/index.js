import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminProblemChecksIndexRoute extends DiscourseRoute {
  titleToken() {
    return i18n("admin.config.problem_checks.title");
  }

  async model() {
    return await ajax("/admin/problem_checks.json");
  }
}
