import Component from "@glimmer/component";
import { getOwner, setOwner } from "@ember/application";
import { inject as service } from "@ember/service";

export default class SidebarApiPanels extends Component {
  @service siteSettings;
  @service currentUser;
  @service site;

  constructor() {
    super(...arguments);

    this.customSections =
      this.args.panel?.sections?.map((customSection) => {
        const section = new customSection();
        setOwner(section, getOwner(this));
        return section;
      }) || [];
  }
}
