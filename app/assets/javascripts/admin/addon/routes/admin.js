import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";

export default class AdminRoute extends DiscourseRoute {
  titleToken() {
    return I18n.t("admin_title");
  }

  activate() {
    this.controllerFor("application").setProperties({
      showTop: false,
    });
  }

  deactivate() {
    this.controllerFor("application").set("showTop", true);
  }
}
