import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { getOwner, setOwner } from "@ember/application";

export default class SidebarApiSections extends Component {
  @service sidebarState;

  get sections() {
    if (this.sidebarState.combinedMode) {
      this.allSections = this.sidebarState.panels
        .map((panel) => panel.sections)
        .flat();
    } else {
      this.allSections = this.sidebarState.currentPanel.sections;
    }

    return this.allSections.map((customSection) => {
      const section = new customSection();
      setOwner(section, getOwner(this));
      return section;
    });
  }
}
