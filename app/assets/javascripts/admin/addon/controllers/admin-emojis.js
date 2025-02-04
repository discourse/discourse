import Controller from "@ember/controller";
import { service } from "@ember/service";

export default class AdminEmojisController extends Controller {
  @service router;

  get hideTabs() {
    return ["adminEmojis.new"].includes(this.router.currentRouteName);
  }
}
