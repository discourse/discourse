import Service from "@ember/service";
import { tracked } from "@glimmer/tracking";

import {
  currentPanelKey,
  customPanels as panels,
} from "discourse/lib/sidebar/custom-sections";

const COMBINED_MODE = "combined";
const SEPARATED_MODE = "separated";
const MAIN_PANEL = "main";

export default class SidebarState extends Service {
  @tracked currentPanelKey = currentPanelKey;
  @tracked panels = panels;
  @tracked mode = COMBINED_MODE;

  constructor() {
    super(...arguments);

    this.#reset();
  }

  setPanel(name) {
    this.currentPanelKey = name;
    this.mode = SEPARATED_MODE;
  }

  get currentPanel() {
    return this.panels.find((panel) => panel.key === this.currentPanelKey);
  }

  setSeparatedMode() {
    this.mode = SEPARATED_MODE;
  }

  setCombinedMode() {
    this.mode = COMBINED_MODE;
    this.currentPanelKey = MAIN_PANEL;
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
}
