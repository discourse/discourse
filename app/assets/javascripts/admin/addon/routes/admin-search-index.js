import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminApiIndexRoute extends DiscourseRoute {
  queryParams = {
    filter: { refreshModel: true },
  };

  titleToken() {
    return i18n("admin.search.title");
  }
}
