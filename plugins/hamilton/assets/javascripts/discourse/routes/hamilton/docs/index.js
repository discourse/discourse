import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class HamiltonDocumentationRoute extends DiscourseRoute {
  model() {
    return ajax("/hamilton/docs.json");
  }

  titleToken() {
    return i18n("hamilton.docs");
  }
}
