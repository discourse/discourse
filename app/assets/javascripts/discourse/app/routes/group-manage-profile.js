import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default class GroupManageProfile extends DiscourseRoute {
  titleToken() {
    return I18n.t("groups.manage.profile.title");
  }
}
