import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";

import {
  customSectionLinks,
  secondaryCustomSectionLinks,
} from "discourse/lib/sidebar/custom-community-section-links";

export default class SidebarCommunitySection extends Component {
  @service router;
  @service topicTrackingState;
  @service currentUser;
  @service appEvents;
  @service site;
  @service siteSettings;

  @tracked sectionLinks;
  @tracked moreSectionLinks;
  @tracked moreSecondarySectionLinks;

  callbackId;
  headerActionsIcon;
  headerActions;

  constructor() {
    super(...arguments);

    this.moreSectionLinks = this.#initializeSectionLinks(
      [...this.defaultMoreSectionLinks, ...customSectionLinks],
      { inMoreDrawer: true }
    );

    this.moreSecondarySectionLinks = this.#initializeSectionLinks(
      [
        ...this.defaultMoreSecondarySectionLinks,
        ...secondaryCustomSectionLinks,
      ],
      { inMoreDrawer: true }
    );

    this.sectionLinks = this.#initializeSectionLinks(
      this.defaultMainSectionLinks,
      { inMoreDrawer: false }
    );

    this.callbackId = this.topicTrackingState.onStateChange(() => {
      this.sectionLinks.forEach((sectionLink) => {
        sectionLink.onTopicTrackingStateChange();
      });
    });
  }

  willDestroy() {
    [
      ...this.sectionLinks,
      ...this.moreSectionLinks,
      ...this.moreSecondarySectionLinks,
    ].forEach((sectionLink) => {
      sectionLink.teardown?.();
    });

    this.topicTrackingState.offStateChange(this.callbackId);
  }

  // Override in child
  get defaultMainSectionLinks() {
    return [];
  }

  // Override in child
  get defaultMoreSectionLinks() {
    return [];
  }

  // Override in child
  get defaultMoreSecondarySectionLinks() {
    return [];
  }

  get isDesktopDropdownMode() {
    const headerDropdownMode =
      this.siteSettings.navigation_menu === "header dropdown";

    return !this.site.mobileView && headerDropdownMode;
  }

  #initializeSectionLinks(sectionLinkClasses, { inMoreDrawer } = {}) {
    return sectionLinkClasses.map((sectionLinkClass) => {
      return this.#initializeSectionLink(sectionLinkClass, inMoreDrawer);
    });
  }

  #initializeSectionLink(sectionLinkClass, inMoreDrawer) {
    return new sectionLinkClass({
      topicTrackingState: this.topicTrackingState,
      currentUser: this.currentUser,
      appEvents: this.appEvents,
      router: this.router,
      siteSettings: this.siteSettings,
      inMoreDrawer,
    });
  }
}
