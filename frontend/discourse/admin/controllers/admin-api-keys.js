import Controller from "@ember/controller";
import { service } from "@ember/service";

export default class AdminApiKeysController extends Controller {
  @service router;

  get hideTabs() {
    return ["adminApiKeys.show"].includes(this.router.currentRouteName);
  }
}
