import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { getOwner } from "@ember/owner";
import { trackedSet } from "@ember/reactive/collections";
import Service, { service } from "@ember/service";
import escapeRegExp from "discourse/lib/escape-regexp";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import {
  currentPanelKey,
  getSidebarPanels,
} from "discourse/lib/sidebar/custom-sections";
import { getCollapsedSidebarSectionKey } from "discourse/lib/sidebar/helpers";
import {
  COMBINED_MODE,
  MAIN_PANEL,
  SEPARATED_MODE,
} from "discourse/lib/sidebar/panels";

@disableImplicitInjections
export default class SidebarState extends Service {
  @service keyValueStore;
  @service router;

  @tracked currentPanelKey = currentPanelKey;
  @tracked mode = COMBINED_MODE;
  @tracked displaySwitchPanelButtons = false;
  @tracked filter = "";
  @tracked isForcingSidebar = false;
  @tracked forcingSidebarPanel = null;

  panels = getSidebarPanels(getOwner(this));
  activeExpandedSections = trackedSet();
  collapsedSections = trackedSet();
  previousState = {};
  #hiders = trackedSet();
  #revealedLinks = new WeakMap();

  get sidebarHidden() {
    return this.#hiders.size > 0;
  }

  get currentPanel() {
    return this.panels.find((panel) => panel.key === this.currentPanelKey);
  }

  get combinedMode() {
    return this.mode === COMBINED_MODE;
  }

  get showMainPanel() {
    return this.currentPanelKey === MAIN_PANEL;
  }

  get sanitizedFilter() {
    return escapeRegExp(this.filter.toLowerCase().trim());
  }

  resetLinkReveal(container) {
    this.#revealedLinks.delete(container);
  }

  shouldRevealLink(container, destination, { force = false, linkRoute } = {}) {
    let state = this.#revealedLinks.get(container);
    const route = this.router.currentRoute;
    const panel = this.currentPanelKey;

    if (
      !state ||
      state.route !== route ||
      state.panel !== panel ||
      state.mode !== this.mode ||
      state.filter !== this.filter
    ) {
      state = {
        route,
        panel,
        mode: this.mode,
        filter: this.filter,
        destinations: new Map(),
      };
      this.#revealedLinks.set(container, state);
    }

    const revealed = state.destinations.get(linkRoute) === destination;
    state.destinations.set(linkRoute, destination);
    return force || !revealed;
  }

  registerHider(ref) {
    this.#hiders.add(ref);

    registerDestructor(ref, () => {
      this.#hiders.delete(ref);
    });
  }

  setPanel(name) {
    if (this.currentPanelKey) {
      this.setPreviousState();
    }
    this.currentPanelKey = name;
    this.restorePreviousState();
  }

  setSeparatedMode() {
    this.mode = SEPARATED_MODE;
    this.showSwitchPanelButtons();
  }

  setCombinedMode() {
    this.mode = COMBINED_MODE;
    this.currentPanelKey = MAIN_PANEL;
    this.hideSwitchPanelButtons();
  }

  showSwitchPanelButtons() {
    this.displaySwitchPanelButtons = true;
  }

  hideSwitchPanelButtons() {
    this.displaySwitchPanelButtons = false;
  }

  setPreviousState() {
    this.previousState[this.currentPanelKey] = {
      mode: this.mode,
      displaySwitchPanelButtons: this.displaySwitchPanelButtons,
    };
  }

  collapseSection(sectionKey) {
    const collapsedSidebarSectionKey =
      getCollapsedSidebarSectionKey(sectionKey);
    this.keyValueStore.setItem(collapsedSidebarSectionKey, true);
    this.collapsedSections.add(collapsedSidebarSectionKey);
    // remove the section from the active expanded list if collapsed later
    this.activeExpandedSections.delete(sectionKey);
  }

  expandSection(sectionKey) {
    const collapsedSidebarSectionKey =
      getCollapsedSidebarSectionKey(sectionKey);
    this.keyValueStore.setItem(collapsedSidebarSectionKey, false);
    this.collapsedSections.delete(collapsedSidebarSectionKey);
    // remove the section from the active expanded list if expanded later
    this.activeExpandedSections.delete(sectionKey);
  }

  isCurrentPanel(panel) {
    return this.currentPanel.key === panel;
  }

  restorePreviousState() {
    const state = this.previousState[this.currentPanelKey];
    if (!state) {
      return;
    }

    if (state.mode === SEPARATED_MODE) {
      this.setSeparatedMode();
    } else if (state.mode === COMBINED_MODE) {
      this.setCombinedMode();
    }

    if (state.displaySwitchPanelButtons) {
      this.showSwitchPanelButtons();
    } else {
      this.hideSwitchPanelButtons();
    }
  }

  clearFilter() {
    this.filter = "";
  }
}
