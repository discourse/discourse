import Component from "@glimmer/component";
import { getOwner, setOwner } from "@ember/application";
import { inject as service } from "@ember/service";

export default class SidebarApiSection extends Component {
  @service sidebarState;

  constructor() {
    super(...arguments);
    this.section = new this.args.sectionConfig();
    setOwner(this.section, getOwner(this));
  }

  get shouldDisplay() {
    if (!this.sidebarState.currentPanel.filterable) {
      return true;
    }
    const shouldDisplay =
      this.sidebarState.filter.length === 0 || this.filteredLinks.length > 0;
    const index = this.sidebarState.filteredOutSections.indexOf(
      this.section.name
    );
    if (shouldDisplay) {
      if (index !== -1) {
        this.sidebarState.filteredOutSections.removeObject(this.section.name);
      }
    } else {
      if (index === -1) {
        this.sidebarState.filteredOutSections.pushObject(this.section.name);
      }
    }
    return shouldDisplay;
  }

  get filteredLinks() {
    if (this.sidebarState.filter) {
      return this.section.links.filter((link) => {
        return link.text
          .toString()
          .toLowerCase()
          .match(this.sidebarState.filter.toLowerCase());
      });
    } else {
      return this.section.links;
    }
  }
}
