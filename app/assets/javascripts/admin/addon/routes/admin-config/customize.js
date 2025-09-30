import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminConfigThemesAndComponentsRoute extends DiscourseRoute {
  @service router;

  titleToken() {
    return i18n("admin.config.themes_and_components.title");
  }
}
