import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

import {
  customSectionLinks,
  secondaryCustomSectionLinks,
} from "discourse/lib/sidebar/custom-community-section-links";

export default class SidebarCommunitySection extends Component {
  @service router;
  @service topicTrackingState;
  @service currentUser;
  @service appEvents;
  @service siteSettings;

  headerActionsIcon;
  headerActions;
  sectionLinks;
  moreSectionLinks;
  moreSecondarySectionLinks;
  callbackId;

  constructor() {
    super(...arguments);

    this.moreSectionLinks = [
      ...this.defaultMoreSectionLinks,
      ...customSectionLinks,
    ].map((sectionLinkClass) => {
      return this.#initializeSectionLink(sectionLinkClass);
    });

    this.moreSecondarySectionLinks = [
      ...this.defaultMoreSecondarySectionLinks,
      ...secondaryCustomSectionLinks,
    ].map((sectionLinkClass) => {
      return this.#initializeSectionLink(sectionLinkClass);
    });

    const mainSectionLinks = this.currentUser?.staff
      ? [...this.defaultMainSectionLinks, ...this.defaultAdminMainSectionLinks]
      : [...this.defaultMainSectionLinks];

    this.sectionLinks = mainSectionLinks.map((sectionLinkClass) => {
      return this.#initializeSectionLink(sectionLinkClass);
    });

    this.callbackId = this.topicTrackingState.onStateChange(() => {
      this.sectionLinks.forEach((sectionLink) => {
        sectionLink.onTopicTrackingStateChange();
      });
    });
  }

  willDestroy() {
    this.sectionLinks.forEach((sectionLink) => sectionLink.teardown());
    this.topicTrackingState.offStateChange(this.callbackId);
  }

  // Override in child
  get defaultMainSectionLinks() {
    return [];
  }

  // Override in child
  get defaultAdminMainSectionLinks() {
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
