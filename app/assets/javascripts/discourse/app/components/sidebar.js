import Component from "@glimmer/component";
import { bind } from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";

export default class Sidebar extends Component {
  @service appEvents;
  @service site;

  constructor() {
    super(...arguments);

    if (this.site.mobileView) {
      document.addEventListener("click", this.collapseSidebar);
    }
    // This appEvent handler is experimental and should not be relied on as an extension point yet.
    this.appEvents.on("sidebar:scroll-to-element", this, this.#scrollToElement);
  }

  @bind
  collapseSidebar(event) {
    let shouldCollapseSidebar = false;

    const isClickWithinSidebar = event.composedPath().some((element) => {
      if (
        element?.className !== "sidebar-section-header-caret" &&
        ["A", "BUTTON"].includes(element.nodeName)
      ) {
        shouldCollapseSidebar = true;
        return true;
      }

      return element.className && element.className === "sidebar-wrapper";
    });

    if (shouldCollapseSidebar || !isClickWithinSidebar) {
      this.args.toggleSidebar();
    }
  }

  #scrollToElement(destinationElement) {
    const topPadding = 10;

    const sidebarContainerElement =
      document.querySelector(".sidebar-container");

    const distanceFromTop =
      document.getElementsByClassName(destinationElement)[0].offsetTop -
      topPadding;

    this.#setMissingHeightForScroll(sidebarContainerElement, distanceFromTop);

    sidebarContainerElement.scrollTop = distanceFromTop;
  }

  #setMissingHeightForScroll(sidebarContainerElement, distanceFromTop) {
    const allSections = document.getElementsByClassName(
      "sidebar-section-wrapper"
    );

    const lastSectionElement = allSections[allSections.length - 1];

    const lastSectionBottomPadding = parseInt(
      lastSectionElement.style.paddingBottom?.replace("px", "") || 0,
      10
    );

    const headerOffset = parseInt(
      document.documentElement.style.getPropertyValue("--header-offset"),
      10
    );

    let allSectionsHeight = 0;

    for (const section of allSections) {
      allSectionsHeight +=
        section.clientHeight +
        parseInt(
          window.getComputedStyle(section).marginBottom.replace("px", ""),
          10
        );
    }

    const missingHeight =
      sidebarContainerElement.clientHeight -
      headerOffset +
      lastSectionBottomPadding -
      (allSectionsHeight - distanceFromTop);

    lastSectionElement.style.paddingBottom =
      missingHeight > 0 ? `${missingHeight}px` : null;
  }

  willDestroy() {
    if (this.site.mobileView) {
      document.removeEventListener("click", this.collapseSidebar);
    }

    this.appEvents.off(
      "sidebar:scroll-to-element",
      this,
      this.#scrollToElement
    );
  }
}
