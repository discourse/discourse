import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class SidebarApiSections extends Component {
  @service sidebarState;

  get sections() {
    if (this.sidebarState.combinedMode) {
      return this.sidebarState.panels.map((panel) => panel.sections).flat();
    } else {
      return this.sidebarState.currentPanel.sections;
    }
  }
}
