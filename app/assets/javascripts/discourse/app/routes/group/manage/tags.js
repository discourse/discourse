import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class GroupManageTags extends DiscourseRoute {
  titleToken() {
    return i18n("groups.manage.tags.title");
  }
}
