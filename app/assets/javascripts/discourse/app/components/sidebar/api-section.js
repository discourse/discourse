import Component from "@glimmer/component";
import { getOwner, setOwner } from "@ember/application";

export default class SidebarApiSection extends Component {
  constructor() {
    super(...arguments);
    this.section = new this.args.sectionConfig();
    setOwner(this.section, getOwner(this));
  }
}
