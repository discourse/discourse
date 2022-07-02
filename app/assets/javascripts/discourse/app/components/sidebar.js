import GlimmerComponent from "discourse/components/glimmer";
import { bind } from "discourse-common/utils/decorators";

export default class Sidebar extends GlimmerComponent {
  constructor() {
    super(...arguments);
    if (this.site.mobileView) {
      document.addEventListener("click", this.mobileOutsideClick);
    }
  }

  _cleanUp() {
    this.args.applicationController.set("showSidebar", false);

    if (this.site.mobileView) {
      document.removeEventListener("click", this.mobileOutsideClick);
      this.appEvents.off("page:changed", this, this._cleanUp);
    }
  }

  @bind
  mobileOutsideClick(event) {
    this.appEvents.on("page:changed", this, this._cleanUp);

    let sidebarParentContainer = event
      .composedPath()
      .filter(
        (element) =>
          element.className && element.className === "sidebar-wrapper"
      );

    if (!sidebarParentContainer.length) {
      this.args.applicationController.set("showSidebar", false);
      document.removeEventListener("click", this.mobileOutsideClick);
    }
  }

  willDestroy() {
    this._cleanUp();
  }
}
