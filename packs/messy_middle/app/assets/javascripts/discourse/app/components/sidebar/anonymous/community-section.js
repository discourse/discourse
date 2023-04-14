import SidebarCommonCommunitySection from "discourse/components/sidebar/common/community-section";
import EverythingSectionLink from "discourse/lib/sidebar/common/community-section/everything-section-link";
import AboutSectionLink from "discourse/lib/sidebar/common/community-section/about-section-link";
import FAQSectionLink from "discourse/lib/sidebar/common/community-section/faq-section-link";
import GroupsSectionLink from "discourse/lib/sidebar/common/community-section/groups-section-link";
import UsersSectionLink from "discourse/lib/sidebar/common/community-section/users-section-link";
import BadgesSectionLink from "discourse/lib/sidebar/common/community-section/badges-section-link";

export default class SidebarAnonymousCommunitySection extends SidebarCommonCommunitySection {
  get defaultMainSectionLinks() {
    const defaultLinks = [
      EverythingSectionLink,
      UsersSectionLink,
      FAQSectionLink,
    ];

    defaultLinks.splice(
      this.displayShortSiteDescription ? 0 : 2,
      0,
      AboutSectionLink
    );

    return defaultLinks;
  }

  get displayShortSiteDescription() {
    return (
      !this.currentUser &&
      (this.siteSettings.short_site_description || "").length > 0
    );
  }

  get defaultMoreSectionLinks() {
    return [GroupsSectionLink, BadgesSectionLink];
  }
}
