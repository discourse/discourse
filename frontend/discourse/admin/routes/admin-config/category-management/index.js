import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminConfigCategoryManagementIndexRoute extends DiscourseRoute {
  @service router;

  beforeModel() {
    this.router.replaceWith("adminConfig.categoryManagement.type", "all");
  }
}
