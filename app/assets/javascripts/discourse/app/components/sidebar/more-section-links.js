import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { bind } from "discourse-common/utils/decorators";

export default class SidebarMoreSectionLinks extends Component {
  @service router;

  @tracked activeSectionLink;
  @tracked open = false;

  constructor() {
    super(...arguments);
    this.#setActiveSectionLink();
    this.router.on("routeDidChange", this, this.#setActiveSectionLink);
  }

  willDestroy() {
    super.willDestroy(...arguments);
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

  get secondarySectionLinks() {
    if (this.activeSectionLink) {
      return this.#filterActiveSectionLink(this.args.secondarySectionLinks);
    } else {
      return this.args.secondarySectionLinks;
    }
  }

  #filterActiveSectionLink(sectionLinks) {
    return sectionLinks.filter((sectionLink) => {
      return sectionLink.name !== this.activeSectionLink.name;
    });
  }

  @bind
  closeDetails(event) {
    if (event.target.closest(".sidebar-more-section-links-details-summary")) {
      return;
    }

    if (this.open) {
      const isLinkClick =
        event.target.className.includes("sidebar-section-link") ||
        event.target.className.includes("--link-button");

      if (isLinkClick || this.#isOutsideDetailsClick(event)) {
        this.open = false;
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
  toggleSectionLinks(event) {
    event.stopPropagation();
    this.open = !this.open;
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
    const activeSectionLink = this.args.sectionLinks.find((sectionLink) => {
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
