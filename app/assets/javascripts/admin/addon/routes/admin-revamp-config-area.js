import Route from "@ember/routing/route";
import { inject as service } from "@ember/service";

export default class AdminRevampConfigAreaRoute extends Route {
  @service router;

  async model(params) {
    return { area: params.area };
  }
}
