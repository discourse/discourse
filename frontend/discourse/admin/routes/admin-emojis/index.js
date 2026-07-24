import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminEmojisIndexRoute extends DiscourseRoute {
  @service adminEmojis;

  deactivate() {
    this.adminEmojis.cancelSelecting();
  }
}
