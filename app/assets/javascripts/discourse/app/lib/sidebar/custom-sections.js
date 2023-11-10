import BaseCustomSidebarPanel from "discourse/lib/sidebar/base-custom-sidebar-panel";
import BaseCustomSidebarSection from "discourse/lib/sidebar/base-custom-sidebar-section";
import BaseCustomSidebarSectionLink from "discourse/lib/sidebar/base-custom-sidebar-section-link";
import I18n from "discourse-i18n";

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

export let customPanels = [new MainSidebarPanel()];

export let currentPanelKey = "main";

export function addSidebarPanel(func) {
  const panelClass = func.call(this, BaseCustomSidebarPanel);
  customPanels.push(new panelClass());
}

export function addSidebarSection(func, panelKey) {
  const panel = customPanels.findBy("key", panelKey);
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
  customPanels = [new MainSidebarPanel()];
  currentPanelKey = "main";
}
