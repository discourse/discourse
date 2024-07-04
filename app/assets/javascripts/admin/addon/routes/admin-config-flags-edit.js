import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class AdminConfigFlagsEditRoute extends Route {
  @service site;

  model(params) {
    return this.site.flagTypes.findBy("id", parseInt(params.flag_id, 10));
  }
}
