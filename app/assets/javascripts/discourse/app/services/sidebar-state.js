import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import {
  currentPanelKey,
  customPanels as panels,
} from "discourse/lib/sidebar/custom-sections";
import {
  COMBINED_MODE,
  MAIN_PANEL,
  SEPARATED_MODE,
} from "discourse/lib/sidebar/panels";

@disableImplicitInjections
export default class SidebarState extends Service {
  @tracked currentPanelKey = currentPanelKey;
  @tracked panels = panels;
  @tracked mode = COMBINED_MODE;
  @tracked displaySwitchPanelButtons = false;
  @tracked filter = "";

  constructor() {
    super(...arguments);
    this.#reset();
  }

  setPanel(name) {
    this.currentPanelKey = name;
  }

  get currentPanel() {
    return this.panels.find((panel) => panel.key === this.currentPanelKey);
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

  get combinedMode() {
    return this.mode === COMBINED_MODE;
  }

  get showMainPanel() {
    return this.currentPanelKey === MAIN_PANEL;
  }

  #reset() {
    this.currentPanelKey = currentPanelKey;
    this.panels = panels;
    this.mode = COMBINED_MODE;
  }

  clearFilter() {
    this.filter = "";
  }
}
