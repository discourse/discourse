import Service from "@ember/service";
import { tracked } from "@glimmer/tracking";
import I18n from "I18n";

import BaseCustomSidebarSection from "discourse/lib/sidebar/base-custom-sidebar-section";
import BaseCustomSidebarPanel from "discourse/lib/sidebar/base-custom-sidebar-panel";
import BaseCustomSidebarSectionLink from "discourse/lib/sidebar/base-custom-sidebar-section-link";

class MainSidebarPanel {
  sections = [];

  get key() {
    return "main";
  }

  get switchButtonLabel() {
    return I18n.t("sidebar.panels.forum.label");
  }

  get switchButtonIcon() {
    return "random";
  }

  get switchButtonDefaultUrl() {
    return "/";
  }
}

const COMBINED_MODE = "combined";
const SEPARATED_MODE = "separated";

export default class SidebarState extends Service {
  @tracked currentPanelKey = "main";
  @tracked panels = [new MainSidebarPanel()];
  @tracked mode = COMBINED_MODE;

  addPanel(func) {
    const panelClass = func.call(this, BaseCustomSidebarPanel);
    this.panels.push(new panelClass());
  }

  setPanel(name) {
    this.currentPanelKey = name;
  }

  get currentPanel() {
    return this.panels.find((panel) => panel.key === this.currentPanelKey);
  }

  setSeparatedMode() {
    this.mode = SEPARATED_MODE;
  }

  setCombinedMode() {
    this.mode = COMBINED_MODE;
  }

  get combinedMode() {
    return this.mode === COMBINED_MODE;
  }

  addSidebarSection(func, panelKey) {
    const panel = this.panels.find((p) => p.key === panelKey);
    if (!panel) {
      // eslint-disable-next-line no-console
      return console.warn(
        `Error adding section to ${panelKey} because panel doens't exist. Check addSidebarPanel API.`
      );
    }
    panel.sections.push(
      func.call(this, BaseCustomSidebarSection, BaseCustomSidebarSectionLink)
    );
  }
}
