import KeyboardShortcutsHelp from "discourse/components/modal/keyboard-shortcuts-help";
import AboutSectionLink from "discourse/lib/sidebar/common/community-section/about-section-link";
import BadgesSectionLink from "discourse/lib/sidebar/common/community-section/badges-section-link";
import FaqSectionLink from "discourse/lib/sidebar/common/community-section/faq-section-link";
import GroupsSectionLink from "discourse/lib/sidebar/common/community-section/groups-section-link";
import UsersSectionLink from "discourse/lib/sidebar/common/community-section/users-section-link";
import AdminSectionLink from "discourse/lib/sidebar/user/community-section/admin-section-link";
import InviteSectionLink from "discourse/lib/sidebar/user/community-section/invite-section-link";
import ReviewSectionLink from "discourse/lib/sidebar/user/community-section/review-section-link";
import DiscourseURL from "discourse/lib/url";
import { i18n } from "discourse-i18n";

// Core's community section links, in server menu order. Reusing
// them keeps who sees what, and the review count, in step with core.
const LINK_GROUPS = [
  [[InviteSectionLink, "Invite"]],
  [
    [AdminSectionLink, "Admin"],
    [ReviewSectionLink, "Review"],
  ],
  [
    [AboutSectionLink, "About"],
    [FaqSectionLink, "FAQ"],
    [GroupsSectionLink, "Groups"],
    [UsersSectionLink, "Users"],
    [BadgesSectionLink, "Badges"],
  ],
];

/**
 * The items for the dropdown on the server name: the homepage, if the theme
 * says so, and the site-wide pages that core's header and sidebar used to
 * link to.
 *
 * @returns {Array} ActionMenu items.
 */
export function serverMenuItems(owner) {
  const router = owner.lookup("service:router");
  const modal = owner.lookup("service:modal");

  const groups = LINK_GROUPS.map((group) =>
    group
      .map(
        ([LinkClass, name]) => new LinkClass(owner, { overriddenName: name })
      )
      .filter((link) => link.shouldDisplay)
      .map((link) => ({
        id: link.name,
        label: link.text,
        icon: link.prefixValue,
        badge: link.badgeText,
        action: () =>
          link.href
            ? DiscourseURL.routeTo(link.href)
            : router.transitionTo(link.route),
      }))
  );

  if (settings.home_link) {
    groups.unshift([
      {
        id: "home",
        label: i18n("home"),
        icon: "house",
        action: () => DiscourseURL.routeTo("/"),
      },
    ]);
  }

  groups.push([
    {
      id: "keyboard-shortcuts",
      label: i18n("keyboard_shortcuts_help.title"),
      icon: "keyboard",
      action: () => modal.show(KeyboardShortcutsHelp),
    },
  ]);

  return groups
    .filter((group) => group.length)
    .flatMap((group, index) => (index ? [{ divider: true }, ...group] : group));
}
