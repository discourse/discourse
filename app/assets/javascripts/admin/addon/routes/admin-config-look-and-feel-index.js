import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminConfigLookAndFeelIndexRoute extends DiscourseRoute {
  @service router;

  beforeModel() {
    this.router.replaceWith("adminConfig.lookAndFeel.themes");
  }
}
