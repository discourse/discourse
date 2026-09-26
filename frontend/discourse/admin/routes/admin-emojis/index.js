import { service } from "discourse/lib/service";
import DiscourseRoute from "discourse/routes/discourse";
import AdminEmojisService from "discourse/admin/services/admin-emojis";

export default class AdminEmojisIndexRoute extends DiscourseRoute {
  @service(() => AdminEmojisService) adminEmojis;

  deactivate() {
    this.adminEmojis.cancelSelecting();
  }
}
