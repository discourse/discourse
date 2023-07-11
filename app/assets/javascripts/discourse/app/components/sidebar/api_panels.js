import Component from "@glimmer/component";
import { getOwner, setOwner } from "@ember/application";
import { inject as service } from "@ember/service";
import { cached } from "@glimmer/tracking";

export default class SidebarApiPanels extends Component {
  @service siteSettings;
  @service currentUser;
  @service site;

  @cached
  get customSections() {
    return this.args.panel.sections.map((customSection) => {
      const section = new customSection({ sidebar: this });
      setOwner(section, getOwner(this));
      return section;
    });
  }
}
