import Component from "@glimmer/component";
import { getOwner, setOwner } from "@ember/application";
import { service } from "@ember/service";

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
    return (
      this.sidebarState.filter.length === 0 || this.filteredLinks.length > 0
    );
  }

  get filteredLinks() {
    if (!this.sidebarState.filter) {
      return this.section.links;
    }
    if (this.section.text.toLowerCase().match(this.sidebarState.filter)) {
      return this.section.links;
    }

    return this.section.links.filter((link) => {
      return (
        link.text.toString().toLowerCase().match(this.sidebarState.filter) ||
        link.keywords.navigation.some((keyword) =>
          keyword.match(this.sidebarState.filter)
        )
      );
    });
  }
}
