import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default class GroupManageTags extends DiscourseRoute {
  titleToken() {
    return I18n.t("groups.manage.tags.title");
  }
}
