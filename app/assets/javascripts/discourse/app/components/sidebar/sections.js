import GlimmerComponent from "discourse/components/glimmer";
import { customSections as sidebarCustomSections } from "discourse/lib/sidebar/custom-sections";

export default class SidebarSections extends GlimmerComponent {
  customSections;

  constructor() {
    super(...arguments);
    this.customSections = this._customSections;
  }

  get _customSections() {
    return sidebarCustomSections.map((customSection) => {
      return new customSection({ sidebar: this });
    });
  }
}
