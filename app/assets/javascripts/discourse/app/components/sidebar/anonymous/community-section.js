import SidebarCommonCommunitySection from "discourse/components/sidebar/common/community-section";
import EverythingSectionLink from "discourse/lib/sidebar/common/community-section/everything-section-link";
import AboutSectionLink from "discourse/lib/sidebar/common/community-section/about-section-link";
import FAQSectionLink from "discourse/lib/sidebar/common/community-section/faq-section-link";
import GroupsSectionLink from "discourse/lib/sidebar/common/community-section/groups-section-link";
import UsersSectionLink from "discourse/lib/sidebar/common/community-section/users-section-link";
import BadgesSectionLink from "discourse/lib/sidebar/common/community-section/badges-section-link";

export default class SidebarAnonymousCommunitySection extends SidebarCommonCommunitySection {
  get defaultMainSectionLinks() {
    return [
      EverythingSectionLink,
      UsersSectionLink,
      AboutSectionLink,
      FAQSectionLink,
    ];
  }

  get defaultMoreSectionLinks() {
    return [GroupsSectionLink, BadgesSectionLink];
  }
}
