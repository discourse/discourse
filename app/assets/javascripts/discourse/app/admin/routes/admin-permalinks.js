import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import Permalink from "admin/models/permalink";

export default class AdminPermalinksRoute extends DiscourseRoute {
  titleToken() {
    return i18n("admin.config.permalinks.title");
  }

  model() {
    return Permalink.findAll();
  }
}
