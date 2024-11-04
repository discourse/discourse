import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default class AdminConfigLookAndFeelRoute extends DiscourseRoute {
  @service router;

  titleToken() {
    return I18n.t("admin.config_areas.look_and_feel.title");
  }
}
