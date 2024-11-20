import BaseCustomSidebarPanel from "discourse/lib/sidebar/base-custom-sidebar-panel";
import BaseCustomSidebarSection from "discourse/lib/sidebar/base-custom-sidebar-section";
import BaseCustomSidebarSectionLink from "discourse/lib/sidebar/base-custom-sidebar-section-link";
import { MAIN_PANEL } from "discourse/lib/sidebar/panels";
import { i18n } from "discourse-i18n";
import AdminSidebarPanel from "./admin-sidebar";

class MainSidebarPanel {
  sections = [];

  get key() {
    return "main";
  }

  get switchButtonLabel() {
    return i18n("sidebar.panels.forum.label");
  }

  get switchButtonIcon() {
    return "shuffle";
  }

  get switchButtonDefaultUrl() {
    return "/";
  }
}

export let customPanels;
export let currentPanelKey;
resetSidebarPanels();

export function addSidebarPanel(func) {
  const panelClass = func.call(this, BaseCustomSidebarPanel);
  customPanels.push(new panelClass());
}

export function addSidebarSection(func, panelKey) {
  const panel = customPanels.findBy("key", panelKey);
  if (!panel) {
    // eslint-disable-next-line no-console
    return console.warn(
      `Error adding section to ${panelKey} because panel doesn't exist. Check addSidebarPanel API.`
    );
  }
  panel.sections.push(
    func.call(this, BaseCustomSidebarSection, BaseCustomSidebarSectionLink)
  );
}

export function resetPanelSections(
  panelKey,
  newSections = null,
  sectionBuilder = null
) {
  const panel = customPanels.findBy("key", panelKey);
  if (newSections) {
    panel.sections = [];
    sectionBuilder(newSections);
  } else {
    panel.sections = [];
  }
}

export function resetSidebarPanels() {
  customPanels = [new MainSidebarPanel(), new AdminSidebarPanel()];
  currentPanelKey = MAIN_PANEL;
}
