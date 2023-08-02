import Component from "@glimmer/component";
import { bind } from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";

export default class Sidebar extends Component {
  @service appEvents;
  @service site;
  @service siteSettings;
  @service currentUser;
  @service sidebarState;

  constructor() {
    super(...arguments);

    if (this.site.mobileView) {
      document.addEventListener("click", this.collapseSidebar);
    }
  }

  get showSwitchPanelButtonsOnTop() {
    return this.siteSettings.default_sidebar_switch_panel_position === "top";
  }

  get switchPanelButtons() {
    if (
      this.sidebarState.combinedMode ||
      this.sidebarState.panels.length === 1 ||
      !this.currentUser
    ) {
      return [];
    }

    return this.sidebarState.panels.filter(
      (panel) => panel !== this.sidebarState.currentPanel
    );
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
