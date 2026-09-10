import { RouteException } from "discourse/controllers/exception";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class extends DiscourseRoute {
  beforeModel() {
    if (!this.currentUser?.admin) {
      throw new RouteException({
        status: 403,
        desc: i18n("explorer.admins_only"),
      });
    }
  }
}
