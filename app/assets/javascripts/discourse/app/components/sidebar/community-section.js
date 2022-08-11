import Component from "@glimmer/component";
import Composer from "discourse/models/composer";
import { getOwner } from "discourse-common/lib/get-owner";
import PermissionType from "discourse/models/permission-type";
import {
  customSectionLinks,
  secondaryCustomSectionLinks,
} from "discourse/lib/sidebar/custom-community-section-links";
import EverythingSectionLink from "discourse/lib/sidebar/community-section/everything-section-link";
import TrackedSectionLink from "discourse/lib/sidebar/community-section/tracked-section-link";
import MyPostsSectionLink from "discourse/lib/sidebar/community-section/my-posts-section-link";
import GroupsSectionLink from "discourse/lib/sidebar/community-section/groups-section-link";
import UsersSectionLink from "discourse/lib/sidebar/community-section/users-section-link";
import AboutSectionLink from "discourse/lib/sidebar/community-section/about-section-link";
import FAQSectionLink from "discourse/lib/sidebar/community-section/faq-section-link";
import AdminSectionLink from "discourse/lib/sidebar/community-section/admin-section-link";

import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { next } from "@ember/runloop";

const MAIN_SECTION_LINKS = [
  EverythingSectionLink,
  TrackedSectionLink,
  MyPostsSectionLink,
];

const ADMIN_MAIN_SECTION_LINKS = [AdminSectionLink];

const MORE_SECTION_LINKS = [GroupsSectionLink, UsersSectionLink];
const MORE_SECONDARY_SECTION_LINKS = [AboutSectionLink, FAQSectionLink];

export default class SidebarCommunitySection extends Component {
  @service router;
  @service topicTrackingState;
  @service currentUser;
  @service appEvents;
  @service siteSettings;

  moreSectionLinks = [...MORE_SECTION_LINKS, ...customSectionLinks].map(
    (sectionLinkClass) => {
      return this.#initializeSectionLink(sectionLinkClass);
    }
  );

  moreSecondarySectionLinks = [
    ...MORE_SECONDARY_SECTION_LINKS,
    ...secondaryCustomSectionLinks,
  ].map((sectionLinkClass) => {
    return this.#initializeSectionLink(sectionLinkClass);
  });

  #mainSectionLinks = this.currentUser.staff
    ? [...MAIN_SECTION_LINKS, ...ADMIN_MAIN_SECTION_LINKS]
    : [...MAIN_SECTION_LINKS];

  sectionLinks = this.#mainSectionLinks.map((sectionLinkClass) => {
    return this.#initializeSectionLink(sectionLinkClass);
  });

  willDestroy() {
    this.sectionLinks.forEach((sectionLink) => sectionLink.teardown());
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

  #initializeSectionLink(sectionLinkClass) {
    return new sectionLinkClass({
      topicTrackingState: this.topicTrackingState,
      currentUser: this.currentUser,
      appEvents: this.appEvents,
      router: this.router,
      siteSettings: this.siteSettings,
    });
  }
}
