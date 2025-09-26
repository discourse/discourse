import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class GroupManageInteraction extends DiscourseRoute {
  titleToken() {
    return i18n("groups.manage.interaction.title");
  }
}
