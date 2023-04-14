import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";

export default class AdminBadgesIndexController extends Controller {
  // Set by the route
  @tracked badgeIntroLinks;
  @tracked badgeIntroEmoji;
}
