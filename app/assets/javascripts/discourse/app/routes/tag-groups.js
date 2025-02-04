import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class TagGroups extends DiscourseRoute {
  model() {
    return this.store.findAll("tagGroup");
  }

  titleToken() {
    return i18n("tagging.groups.title");
  }
}
