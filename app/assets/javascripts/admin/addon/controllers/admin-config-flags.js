import Controller from "@ember/controller";
import { service } from "@ember/service";

export default class AdminConfigFlagsController extends Controller {
  @service router;

  get shouldDisplayHeader() {
    return ["adminConfig.flags.index", "adminConfig.flags.settings"].includes(
      this.router.currentRouteName
    );
  }
}
