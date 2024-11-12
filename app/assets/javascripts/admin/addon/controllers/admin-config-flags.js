import Controller from "@ember/controller";
import { service } from "@ember/service";

export default class AdminConfigFlagsController extends Controller {
  @service router;

  get hideTabs() {
    return ["adminConfig.flags.new", "adminConfig.flags.edit"].includes(
      this.router.currentRouteName
    );
  }
}
