import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default class AdminConfigFlagsEditRoute extends DiscourseRoute {
  @service site;

  model(params) {
    return this.site.flagTypes.findBy("id", parseInt(params.flag_id, 10));
  }

  titleToken() {
    return I18n.t("admin.config_areas.flags.edit_header");
  }
}
