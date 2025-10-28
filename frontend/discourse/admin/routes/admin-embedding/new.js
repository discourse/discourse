import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminEmbeddingNewRoute extends DiscourseRoute {
  titleToken() {
    return i18n("admin.embedding.host_form.add_header");
  }
}
