import { tracked } from "@glimmer/tracking";
import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import AboutSectionLink from "discourse/lib/sidebar/common/community-section/about-section-link";
import BadgesSectionLink from "discourse/lib/sidebar/common/community-section/badges-section-link";
import EverythingSectionLink from "discourse/lib/sidebar/common/community-section/everything-section-link";
import FAQSectionLink from "discourse/lib/sidebar/common/community-section/faq-section-link";
import GroupsSectionLink from "discourse/lib/sidebar/common/community-section/groups-section-link";
import UsersSectionLink from "discourse/lib/sidebar/common/community-section/users-section-link";
import {
  customSectionLinks,
  secondaryCustomSectionLinks,
} from "discourse/lib/sidebar/custom-community-section-links";
import SectionLink from "discourse/lib/sidebar/section-link";
import AdminSectionLink from "discourse/lib/sidebar/user/community-section/admin-section-link";
import InviteSectionLink from "discourse/lib/sidebar/user/community-section/invite-section-link";
import MyPostsSectionLink from "discourse/lib/sidebar/user/community-section/my-posts-section-link";
import ReviewSectionLink from "discourse/lib/sidebar/user/community-section/review-section-link";

const SPECIAL_LINKS_MAP = {
  "/latest": EverythingSectionLink,
  "/about": AboutSectionLink,
  "/u": UsersSectionLink,
  "/faq": FAQSectionLink,
  "/my/activity": MyPostsSectionLink,
  "/review": ReviewSectionLink,
  "/badges": BadgesSectionLink,
  "/admin": AdminSectionLink,
  "/g": GroupsSectionLink,
  "/new-invite": InviteSectionLink,
};

export default class CommunitySection {
  @service appEvents;
  @service currentUser;
  @service modal;
  @service router;
  @service siteSettings;
  @service topicTrackingState;

  @tracked links;
  @tracked moreLinks;

  hideSectionHeader = true;

  constructor({ section, owner }) {
    setOwner(this, owner);

    this.section = section;
    this.slug = section.slug;

    this.callbackId = this.topicTrackingState?.onStateChange(() => {
      this.links.forEach((link) => {
        if (link.onTopicTrackingStateChange) {
          link.onTopicTrackingStateChange();
        }
      });
    });

    this.apiPrimaryLinks = customSectionLinks.map((link) =>
      this.#initializeSectionLink(link, { inMoreDrawer: false })
    );

    this.apiSecondaryLinks = secondaryCustomSectionLinks.map((link) =>
      this.#initializeSectionLink(link, { inMoreDrawer: true })
    );

    this.links = this.section.links
      .reduce((filtered, link) => {
        if (link.segment === "primary") {
          const generatedLink = this.#generateLink(link);

          if (generatedLink) {
            filtered.push(generatedLink);
          }
        }

        return filtered;
      }, [])
      .concat(this.apiPrimaryLinks);

    this.moreLinks = this.section.links
      .reduce((filtered, link) => {
        if (link.segment === "secondary") {
          const generatedLink = this.#generateLink(link, true);

          if (generatedLink) {
            filtered.push(generatedLink);
          }
        }

        return filtered;
      }, [])
      .concat(this.apiSecondaryLinks);
  }

  teardown() {
    if (this.callbackId) {
      this.topicTrackingState.offStateChange(this.callbackId);
    }

    [...this.links, ...this.moreLinks].forEach((sectionLink) => {
      sectionLink.teardown?.();
    });
  }

  #generateLink(link, inMoreDrawer = false) {
    const sectionLinkClass = SPECIAL_LINKS_MAP[link.value];

    if (sectionLinkClass) {
      return this.#initializeSectionLink(
        sectionLinkClass,
        inMoreDrawer,
        link.name,
        link.icon
      );
    } else {
      return new SectionLink(link, this, this.router);
    }
  }

  #initializeSectionLink(
    sectionLinkClass,
    inMoreDrawer,
    overridenName,
    overridenIcon
  ) {
    if (this.router.isDestroying) {
      return;
    }
    return new sectionLinkClass({
      topicTrackingState: this.topicTrackingState,
      currentUser: this.currentUser,
      appEvents: this.appEvents,
      router: this.router,
      siteSettings: this.siteSettings,
      inMoreDrawer,
      overridenName,
      overridenIcon,
    });
  }
}
