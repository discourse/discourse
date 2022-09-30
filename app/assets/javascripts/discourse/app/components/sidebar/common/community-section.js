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
  @service siteSettings;

  @tracked sectionLinks;
  @tracked moreSectionLinks;
  @tracked moreSecondarySectionLinks;

  callbackId;
  headerActionsIcon;
  headerActions;

  constructor() {
    super(...arguments);

    this.refreshSectionLinks();

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

  refreshSectionLinks() {
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
