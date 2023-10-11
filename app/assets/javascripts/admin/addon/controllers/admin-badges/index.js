import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";

export default class AdminBadgesIndexController extends Controller {
  // Set by the route
  @tracked badgeIntroLinks;
  @tracked badgeIntroEmoji;
}
