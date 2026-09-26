import { service } from "discourse/lib/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import SiteService from "discourse/services/site";

export default class AdminConfigFlagsEditRoute extends DiscourseRoute {
  @service(() => SiteService) site;

  model(params) {
    return this.site.flagTypes.find(
      (value) => value.id === parseInt(params.flag_id, 10)
    );
  }

  titleToken() {
    return i18n("admin.config_areas.flags.edit_header");
  }
}
