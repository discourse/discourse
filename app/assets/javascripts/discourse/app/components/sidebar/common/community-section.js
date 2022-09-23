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

    this.moreSectionLinks = this.#initializeSectionLinks([
      ...this.defaultMoreSectionLinks,
      ...customSectionLinks,
    ]);

    this.moreSecondarySectionLinks = this.#initializeSectionLinks([
      ...this.defaultMoreSecondarySectionLinks,
      ...secondaryCustomSectionLinks,
    ]);

    this.sectionLinks = this.#initializeSectionLinks(
      this.defaultMainSectionLinks
    );

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
  get defaultMoreSectionLinks() {
    return [];
  }

  // Override in child
  get defaultMoreSecondarySectionLinks() {
    return [];
  }

  #initializeSectionLinks(sectionLinkClasses) {
    return sectionLinkClasses.reduce((links, sectionLinkClass) => {
      const sectionLink = this.#initializeSectionLink(sectionLinkClass);

      if (sectionLink.shouldDisplay) {
        links.push(sectionLink);
      }

      return links;
    }, []);
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
