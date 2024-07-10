import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default class TagGroups extends DiscourseRoute {
  model() {
    return this.store.findAll("tagGroup");
  }

  titleToken() {
    return I18n.t("tagging.groups.title");
  }
}
