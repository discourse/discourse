import I18n from "I18n";
import SectionLink from "discourse/lib/sidebar/section-link";
import { setOwner } from "@ember/application";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import EverythingSectionLink from "discourse/lib/sidebar/common/community-section/everything-section-link";
import MyPostsSectionLink from "discourse/lib/sidebar/user/community-section/my-posts-section-link";
import AdminSectionLink from "discourse/lib/sidebar/user/community-section/admin-section-link";
import AboutSectionLink from "discourse/lib/sidebar/common/community-section/about-section-link";
import FAQSectionLink from "discourse/lib/sidebar/common/community-section/faq-section-link";
import UsersSectionLink from "discourse/lib/sidebar/common/community-section/users-section-link";
import GroupsSectionLink from "discourse/lib/sidebar/common/community-section/groups-section-link";
import BadgesSectionLink from "discourse/lib/sidebar/common/community-section/badges-section-link";
import ReviewSectionLink from "discourse/lib/sidebar/user/community-section/review-section-link";
import NewTopicSectionButton from "discourse/lib/sidebar/user/community-section/new-topic-section-button";
import {
  customSectionLinks,
  secondaryCustomSectionLinks,
} from "discourse/lib/sidebar/custom-community-section-links";
import showModal from "discourse/lib/show-modal";

const LINKS_IN_BOTH_SEGMENTS = ["/review"];

const SPECIAL_LINKS_MAP = {
  "/latest": EverythingSectionLink,
  "/new": EverythingSectionLink,
  "/about": AboutSectionLink,
  "/u": UsersSectionLink,
  "/faq": FAQSectionLink,
  "/my/activity": MyPostsSectionLink,
  "/review": ReviewSectionLink,
  "/badges": BadgesSectionLink,
  "/admin": AdminSectionLink,
  "/g": GroupsSectionLink,
  "/new-topic": NewTopicSectionButton,
};

export default class CommunitySection {
  @service appEvents;
  @service currentUser;
  @service router;
  @service topicTrackingState;
  @service siteSettings;

  @tracked links;
  @tracked moreLinks;

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

    this.apiLinks = customSectionLinks
      .concat(secondaryCustomSectionLinks)
      .map((link) => this.#initializeSectionLink(link, { inMoreDrawer: true }));

    this.links = this.section.links.reduce((filtered, link) => {
      if (
        link.segment === "primary" ||
        LINKS_IN_BOTH_SEGMENTS.includes(link.value)
      ) {
        const generatedLink = this.#generateLink(link);

        if (generatedLink) {
          filtered.push(generatedLink);
        }
      }

      return filtered;
    }, []);

    this.moreLinks = this.section.links
      .reduce((filtered, link) => {
        if (
          link.segment === "secondary" ||
          LINKS_IN_BOTH_SEGMENTS.includes(link.value)
        ) {
          const generatedLink = this.#generateLink(link, true);

          if (generatedLink) {
            filtered.push(generatedLink);
          }
        }

        return filtered;
      }, [])
      .concat(this.apiLinks);
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

  get description() {
    if (!this.currentUser && !!this.siteSettings.short_site_description) {
      return this.siteSettings.short_site_description;
    } else {
      return "";
    }
  }

  get decoratedTitle() {
    return I18n.t(
      `sidebar.sections.${this.section.title.toLowerCase()}.header_link_text`,
      { defaultValue: this.section.title }
    );
  }

  get headerActions() {
    if (this.currentUser) {
      return [
        {
          action: this.editSection,
          title: I18n.t("sidebar.sections.community.header_action_title"),
        },
      ];
    }
  }

  get headerActionIcon() {
    return "pencil-alt";
  }

  @action
  editSection() {
    showModal("sidebar-section-form", { model: this.section });
  }
}
