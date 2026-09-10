import ApplicationInstance from "@ember/application/instance";
import { registerDestructor } from "@ember/destroyable";
import { setOwner } from "@ember/owner";
import BaseCustomSidebarPanel from "discourse/lib/sidebar/base-custom-sidebar-panel";
import BaseCustomSidebarSection from "discourse/lib/sidebar/base-custom-sidebar-section";
import BaseCustomSidebarSectionLink from "discourse/lib/sidebar/base-custom-sidebar-section-link";
import { MAIN_PANEL } from "discourse/lib/sidebar/panels";
import { i18n } from "discourse-i18n";
import AdminSidebarPanel from "./admin-sidebar";

class MainSidebarPanel extends BaseCustomSidebarPanel {
  scrollActiveLinkIntoView = true;
  expandActiveSection = false;

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
    return this?.lastKnownURL || "/";
  }
}

export let customPanels;
export let currentPanelKey;
const panelsByOwner = new Map();
let panelSources = new WeakMap();
let registeredSections = new WeakMap();
resetSidebarPanels();

function instantiatePanel(source, owner) {
  const panel = new source.constructor();
  setOwner(panel, owner);
  panelSources.set(panel, source);
  for (const section of registeredSections.get(source) || []) {
    panel.sections.push(section);
  }
  return panel;
}

export function getSidebarPanels(owner) {
  if (!(owner instanceof ApplicationInstance)) {
    return customPanels;
  }

  let panels = panelsByOwner.get(owner);
  if (!panels) {
    panels = customPanels.map((panel) => instantiatePanel(panel, owner));
    panelsByOwner.set(owner, panels);
    registerDestructor(owner, () => panelsByOwner.delete(owner));
  }
  return panels;
}

export function addSidebarPanel(func, { owner } = {}) {
  const panelClass = func.call(this, BaseCustomSidebarPanel);
  const panel = new panelClass();
  if (owner) {
    setOwner(panel, owner);
  }
  const panels = getSidebarPanels(owner);
  panels.push(panel);

  if (panels === customPanels) {
    for (const [instanceOwner, instancePanels] of panelsByOwner) {
      instancePanels.push(instantiatePanel(panel, instanceOwner));
    }
    if (owner) {
      registerDestructor(owner, () => {
        const index = panels.indexOf(panel);
        if (index !== -1) {
          panels.splice(index, 1);
        }
        const sources = panelSources;
        for (const instancePanels of panelsByOwner.values()) {
          const instanceIndex = instancePanels.findIndex(
            (instancePanel) => sources.get(instancePanel) === panel
          );
          if (instanceIndex !== -1) {
            instancePanels.splice(instanceIndex, 1);
          }
        }
      });
    }
  }
}

export function addSidebarSection(func, panelKey, { owner } = {}) {
  const panels = getSidebarPanels(owner);
  const panel = panels.find((p) => p.key === panelKey);
  if (!panel) {
    // eslint-disable-next-line no-console
    return console.warn(
      `Error adding section to ${panelKey} because panel doesn't exist. Check addSidebarPanel API.`
    );
  }
  const section = func.call(
    this,
    BaseCustomSidebarSection,
    BaseCustomSidebarSectionLink
  );
  panel.sections.push(section);

  if (panels === customPanels) {
    const sections = registeredSections.get(panel) || [];
    registeredSections.set(panel, sections);
    sections.push(section);
    const sources = panelSources;
    for (const instancePanels of panelsByOwner.values()) {
      instancePanels
        .find((instancePanel) => sources.get(instancePanel) === panel)
        ?.sections.push(section);
    }
    if (owner) {
      registerDestructor(owner, () => {
        const registeredIndex = sections.indexOf(section);
        if (registeredIndex !== -1) {
          sections.splice(registeredIndex, 1);
        }
        const allPanels = [panel];
        const currentSources = panelSources;
        for (const instancePanels of panelsByOwner.values()) {
          allPanels.push(
            ...instancePanels.filter(
              (instancePanel) => currentSources.get(instancePanel) === panel
            )
          );
        }
        for (const registeredPanel of allPanels) {
          const index = registeredPanel.sections.indexOf(section);
          if (index !== -1) {
            registeredPanel.sections.splice(index, 1);
          }
        }
      });
    }
  }
}

export function resetPanelSections(
  panelKey,
  newSections = null,
  sectionBuilder = null
) {
  const panel = customPanels.find((item) => item.key === panelKey);
  registeredSections.set(panel, []);
  const sources = panelSources;
  for (const instancePanels of panelsByOwner.values()) {
    const instancePanel = instancePanels.find(
      (candidate) => sources.get(candidate) === panel
    );
    if (instancePanel) {
      instancePanel.sections = [];
    }
  }
  if (newSections) {
    panel.sections = [];
    sectionBuilder(newSections);
  } else {
    panel.sections = [];
  }
}

export function resetSidebarPanels() {
  panelsByOwner.clear();
  panelSources = new WeakMap();
  registeredSections = new WeakMap();
  customPanels = [new MainSidebarPanel(), new AdminSidebarPanel()];
  currentPanelKey = MAIN_PANEL;
}
