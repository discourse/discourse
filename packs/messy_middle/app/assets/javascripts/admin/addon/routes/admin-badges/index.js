import Route from "@ember/routing/route";
import { emojiUrlFor } from "discourse/lib/text";

const badgeIntroLinks = [
  {
    text: "admin.badges.badge_intro.what_are_badges_title",
    href: "https://meta.discourse.org/t/32540",
    icon: "book",
  },
  {
    text: "admin.badges.badge_intro.badge_query_examples_title",
    href: "https://meta.discourse.org/t/18978",
    icon: "book",
  },
];

export default class AdminBadgesIndexRoute extends Route {
  setupController(controller) {
    controller.badgeIntroLinks = badgeIntroLinks;
    controller.badgeIntroEmoji = emojiUrlFor("woman_student:t4");
  }
}
