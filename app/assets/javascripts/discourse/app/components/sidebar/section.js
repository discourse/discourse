import GlimmerComponent from "discourse/components/glimmer";

import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class SidebarSection extends GlimmerComponent {
  @tracked displaySection = true;

  @action
  toggleSectionDisplay() {
    this.displaySection = !this.displaySection;
  }

  get headerCaretIcon() {
    return this.displaySection ? "angle-down" : "angle-up";
  }
}
