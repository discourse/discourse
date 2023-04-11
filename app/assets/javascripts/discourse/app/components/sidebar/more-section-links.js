import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { isEmpty } from "@ember/utils";

import { bind } from "discourse-common/utils/decorators";
import Component from "@glimmer/component";

export default class SidebarMoreSectionLinks extends Component {
  @service router;

  @tracked shouldDisplaySectionLinks = false;
  @tracked activeSectionLink;

  #allLinks = [...this.args.sectionLinks];

  constructor() {
    super(...arguments);
    this.#setActiveSectionLink();
    this.router.on("routeDidChange", this, this.#setActiveSectionLink);
  }

  willDestroy() {
    this.#removeClickEventListener();
    this.router.off("routeDidChange", this, this.#setActiveSectionLink);
  }

  get sectionLinks() {
    if (this.activeSectionLink) {
      return this.#filterActiveSectionLink(this.args.sectionLinks);
    } else {
      return this.args.sectionLinks;
    }
  }

  #filterActiveSectionLink(sectionLinks) {
    return sectionLinks.filter((sectionLink) => {
      return sectionLink.name !== this.activeSectionLink.name;
    });
  }

  @bind
  closeDetails(event) {
    if (this.shouldDisplaySectionLinks) {
      const isLinkClick = event.target.className.includes(
        "sidebar-section-link"
      );

      if (isLinkClick || this.#isOutsideDetailsClick(event)) {
        document
          .querySelector(".sidebar-more-section-links-details")
          ?.removeAttribute("open");
      }
    }
  }

  @action
  registerClickListener() {
    this.#addClickEventListener();
  }

  @action
  unregisterClickListener() {
    this.#removeClickEventListener();
  }

  @action
  toggleSectionLinks(element) {
    this.shouldDisplaySectionLinks = element.target.hasAttribute("open");
  }

  #removeClickEventListener() {
    document.removeEventListener("click", this.closeDetails);
  }

  #addClickEventListener() {
    document.addEventListener("click", this.closeDetails);
  }

  #isOutsideDetailsClick(event) {
    return !event.composedPath().some((element) => {
      return element.className === "sidebar-more-section-links-details";
    });
  }

  #setActiveSectionLink() {
    const activeSectionLink = this.#allLinks.find((sectionLink) => {
      const args = [sectionLink.route];

      if (sectionLink.model) {
        args.push(sectionLink.model);
      } else if (sectionLink.models) {
        args.push(...sectionLink.models);
      }

      if (!isEmpty(sectionLink.query)) {
        args.push({ queryParams: sectionLink.query });
      }

      return this.router.isActive(...args) && sectionLink;
    });

    this.activeSectionLink = activeSectionLink;
  }
}
