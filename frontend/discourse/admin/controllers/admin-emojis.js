import Controller from "@ember/controller";
import { service } from "@ember/service";

export default class AdminEmojisController extends Controller {
  @service router;

  get hideTabs() {
    return ["adminEmojis.new", "adminEmojis.import"].includes(
      this.router.currentRouteName
    );
  }
}
