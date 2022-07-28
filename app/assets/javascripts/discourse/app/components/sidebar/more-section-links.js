import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { bind } from "discourse-common/utils/decorators";
import GlimmerComponent from "discourse/components/glimmer";

export default class SidebarMoreSectionLinks extends GlimmerComponent {
  @tracked shouldDisplaySectionLinks = false;
  @tracked activeSectionLink;
  @service router;

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
      return this.args.sectionLinks.filter((sectionLink) => {
        return sectionLink.name !== this.activeSectionLink.name;
      });
    } else {
      return this.args.sectionLinks;
    }
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

        this.toggleSectionLinks();
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
  toggleSectionLinks() {
    this.shouldDisplaySectionLinks = !this.shouldDisplaySectionLinks;
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
      }

      return this.router.isActive(...args) && sectionLink;
    });

    this.activeSectionLink = activeSectionLink;
  }
}
