import Component from "@glimmer/component";
import { bind } from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";
import {
  bottomSidebarButtons,
  topSidebarButtons,
} from "discourse/lib/sidebar/custom-buttons";
import { getOwner, setOwner } from "@ember/application";
import { tracked } from "@glimmer/tracking";

export default class Sidebar extends Component {
  @service appEvents;
  @service site;
  @service router;
  @service currentUser;

  @tracked customCssClasses = [];

  constructor() {
    super(...arguments);

    if (this.site.mobileView) {
      document.addEventListener("click", this.collapseSidebar);
    }

    this.topSidebarButtons = topSidebarButtons.map((customButton) => {
      const button = new customButton({ sidebar: this, router: this.router });
      setOwner(button, getOwner(this));
      return button;
    });

    this.bottomSidebarButtons = bottomSidebarButtons.map((customButton) => {
      const button = new customButton({ sidebar: this, router: this.router });
      setOwner(button, getOwner(this));
      return button;
    });
  }

  get joinedCustomCssClasses() {
    return this.customCssClasses.join(" ");
  }

  @bind
  toggleCssClass(className) {
    if (this.customCssClasses.includes(className)) {
      this.customCssClasses.removeObject(className);
    } else {
      this.customCssClasses.pushObject(className);
    }
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

  willDestroy() {
    if (this.site.mobileView) {
      document.removeEventListener("click", this.collapseSidebar);
    }
  }
}
