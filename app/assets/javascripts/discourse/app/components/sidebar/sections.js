import GlimmerComponent from "discourse/components/glimmer";
import { customSections as sidebarCustomSections } from "discourse/lib/sidebar/custom-sections";
import { getOwner, setOwner } from "@ember/application";

export default class SidebarSections extends GlimmerComponent {
  customSections;

  constructor() {
    super(...arguments);
    this.customSections = this._customSections;
  }

  get _customSections() {
    return sidebarCustomSections.map((customSection) => {
      const section = new customSection({ sidebar: this });
      setOwner(section, getOwner(this));
      return section;
    });
  }
}
