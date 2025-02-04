import Route from "@ember/routing/route";
import { emojiUrlFor } from "discourse/lib/text";

export default class AdminBadgesIndexRoute extends Route {
  setupController(controller) {
    controller.badgeIntroEmoji = emojiUrlFor("woman_student:t4");
  }
}
