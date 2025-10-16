import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminConfigThemesAndComponentsIndexRoute extends DiscourseRoute {
  @service router;

  beforeModel() {
    this.router.replaceWith("adminConfig.customize.themes");
  }
}
