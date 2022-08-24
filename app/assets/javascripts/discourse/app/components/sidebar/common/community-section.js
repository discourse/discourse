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

  // Override in child
  defaultMainSectionLinks = [];
  defaultAdminMainSectionLinks = [];
  defaultMoreSectionLinks = [];
  defaultMoreSecondarySectionLinks = [];
  headerActionsIcon;
  headerActions;

  get moreSectionLinks() {
    return [...this.defaultMoreSectionLinks, ...customSectionLinks].map(
      (sectionLinkClass) => {
        return this.#initializeSectionLink(sectionLinkClass);
      }
    );
  }

  get moreSecondarySectionLinks() {
    return [
      ...this.defaultMoreSecondarySectionLinks,
      ...secondaryCustomSectionLinks,
    ].map((sectionLinkClass) => {
      return this.#initializeSectionLink(sectionLinkClass);
    });
  }

  get mainSectionLinks() {
    return this.currentUser?.staff
      ? [...this.defaultMainSectionLinks, ...this.defaultAdminMainSectionLinks]
      : [...this.defaultMainSectionLinks];
  }

  get sectionLinks() {
    return this.mainSectionLinks.map((sectionLinkClass) => {
      return this.#initializeSectionLink(sectionLinkClass);
    });
  }

  willDestroy() {
    this.sectionLinks.forEach((sectionLink) => sectionLink.teardown());
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
