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
    return this.sidebarState.filter.length === 0 || this.filteredLinks.length > 0;
  }

  get filteredLinks() {
    if (!this.sidebarState.filter) {
      return this.section.links;
    }
    const filterText = this.sidebarState.filter.toLowerCase();
    if (this.section.text.toLowerCase().match(filterText)) {
      return this.section.links;
    }
    return this.section.links.filter((link) => {
      return link.text.toString().toLowerCase().match(filterText);
    });
  }
}
