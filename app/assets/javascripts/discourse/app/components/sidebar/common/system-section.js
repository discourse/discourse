import I18n from "I18n";
import SectionLink from "discourse/components/sidebar/user/section-link";
import Composer from "discourse/models/composer";
import { getOwner } from "discourse-common/lib/get-owner";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import PermissionType from "discourse/models/permission-type";
import EverythingSectionLink from "discourse/lib/sidebar/common/community-section/everything-section-link";
import MyPostsSectionLink from "discourse/lib/sidebar/user/community-section/my-posts-section-link";
import AdminSectionLink from "discourse/lib/sidebar/user/community-section/admin-section-link";
import AboutSectionLink from "discourse/lib/sidebar/common/community-section/about-section-link";
import FAQSectionLink from "discourse/lib/sidebar/common/community-section/faq-section-link";
import UsersSectionLink from "discourse/lib/sidebar/common/community-section/users-section-link";
import GroupsSectionLink from "discourse/lib/sidebar/common/community-section/groups-section-link";
import BadgesSectionLink from "discourse/lib/sidebar/common/community-section/badges-section-link";
import ReviewSectionLink from "discourse/lib/sidebar/user/community-section/review-section-link";
import {
  customSectionLinks,
  secondaryCustomSectionLinks,
} from "discourse/lib/sidebar/custom-community-section-links";

const LINKS_IN_BOTH_SEGMENTS = ["/review"];
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
};

export default class SystemSection {
  @tracked links;
  @tracked moreLinks;

  constructor({
    section,
    currentUser,
    router,
    topicTrackingState,
    appEvents,
    siteSettings,
  }) {
    this.section = section;
    this.router = router;
    this.currentUser = currentUser;
    this.slug = section.slug;
    this.topicTrackingState = topicTrackingState;
    this.appEvents = appEvents;
    this.siteSettings = siteSettings;
    this.system = section.system;

    this.callbackId = this.topicTrackingState?.onStateChange(() => {
      this.links.forEach((link) => {
        if (link.onTopicTrackingStateChange) {
          link.onTopicTrackingStateChange();
        }
      });
    });

    this.apiLinks = customSectionLinks
      .concat(secondaryCustomSectionLinks)
      .map((link) => this.#initializeSectionLink(link, { inMoreDrawer: true }));

    this.links = this.section.links
      .filter(
        (link) =>
          link.segment === "primary" ||
          LINKS_IN_BOTH_SEGMENTS.includes(link.value)
      )
      .map((link) => {
        return this.#generateLink(link);
      })
      .filter((link) => link);

    this.moreLinks = this.section.links
      .filter(
        (link) =>
          link.segment === "secondary" ||
          LINKS_IN_BOTH_SEGMENTS.includes(link.value)
      )
      .map((link) => {
        return this.#generateLink(link, true);
      })
      .concat(this.apiLinks)
      .filter((link) => link);
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
      return this.#initializeSectionLink(sectionLinkClass, inMoreDrawer);
    } else {
      return new SectionLink(link, this, this.router);
    }
  }

  #initializeSectionLink(sectionLinkClass, inMoreDrawer) {
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
    });
  }

  get displayShortSiteDescription() {
    return (
      !this.currentUser &&
      !!this.siteSettings.short_site_description
    );
  }

  get decoratedTitle() {
    return I18n.t(
      `sidebar.sections.${this.section.title.toLowerCase()}.header_link_text`
    );
  }

  get headerActions() {
    if (this.currentUser) {
      return [
        {
          action: this.composeTopic,
          title: I18n.t("sidebar.sections.community.header_action_title"),
        },
      ];
    }
  }

  get headerActionIcon() {
    return "plus";
  }

  @action
  composeTopic() {
    const composerArgs = {
      action: Composer.CREATE_TOPIC,
      draftKey: Composer.NEW_TOPIC_KEY,
    };

    const controller = getOwner(this).lookup("controller:navigation/category");
    const category = controller.category;

    if (category && category.permission === PermissionType.FULL) {
      composerArgs.categoryId = category.id;
    }

    next(() => {
      getOwner(this).lookup("controller:composer").open(composerArgs);
    });
  }
}
