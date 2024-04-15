import Component from "@glimmer/component";
import { service } from "@ember/service";

export default class SidebarApiSections extends Component {
  @service sidebarState;

  get sections() {
    if (this.sidebarState.combinedMode) {
      return this.sidebarState.panels
        .filter((panel) => !panel.hidden)
        .map((panel) => panel.sections)
        .flat();
    } else {
      return this.sidebarState.currentPanel.sections;
    }
  }
}
