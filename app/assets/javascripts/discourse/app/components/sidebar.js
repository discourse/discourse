import GlimmerComponent from "discourse/components/glimmer";
import { bind } from "discourse-common/utils/decorators";

export default class Sidebar extends GlimmerComponent {
  constructor() {
    super(...arguments);

    if (this.site.mobileView) {
      document.addEventListener("click", this.collapseSidebar);
    }
    this.appEvents.on("sidebar:scroll-to-element", this.scrollToElement);
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
  @bind
  scrollToElement(destinationElement) {
    const topPadding = 10;
    const sidebarContainerElement =
      document.querySelector(".sidebar-container");

    const sidebarSectionsElement =
      document.querySelector(".sidebar-sections");
    const allSections = document.getElementsByClassName(
      "sidebar-section-wrapper"
    );
    const lastSectionElement = allSections[allSections.length - 1];
    const distanceFromTop =
      document.getElementsByClassName(destinationElement)[0].offsetTop -
      topPadding;
    const missingHeight =
      sidebarContainerElement.clientHeight -
      (sidebarSectionsElement.clientHeight - distanceFromTop);

    if (missingHeight > 0) {
      const headerOffset = parseInt(
        document.documentElement.style.getPropertyValue("--header-offset"),
        10
      );
      lastSectionElement.style.height = `${
        lastSectionElement.clientHeight + missingHeight - headerOffset
      }px`;
    } else {
      lastSectionElement.style.height = null;
    }

    sidebarContainerElement.scrollTop = distanceFromTop;
  }

  willDestroy() {
    if (this.site.mobileView) {
      document.removeEventListener("click", this.collapseSidebar);
    }
    this.appEvents.off("sidebar:scroll-to-element", this.scrollToElement);
  }
}
