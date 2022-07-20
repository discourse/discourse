import GlimmerComponent from "discourse/components/glimmer";

import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class SidebarSection extends GlimmerComponent {
  @tracked displaySection;
  collapsedSidebarSectionKey = `sidebar-section-${this.args.sectionName}-collapsed`;

  constructor() {
    super(...arguments);

    this.displaySection =
      this.keyValueStore.getItem(this.collapsedSidebarSectionKey) === undefined
        ? true
        : false;
  }

  willDestroy() {
    if (this.args.willDestroy) {
      this.args.willDestroy();
    }
  }

  @action
  toggleSectionDisplay() {
    this.displaySection = !this.displaySection;

    if (this.displaySection) {
      this.keyValueStore.remove(this.collapsedSidebarSectionKey);
    } else {
      this.keyValueStore.setItem(this.collapsedSidebarSectionKey, true);
    }
  }

  @action
  handleMultipleHeaderActions(id) {
    this.args.headerActions
      .find((headerAction) => headerAction.id === id)
      .action();
  }

  get headerCaretIcon() {
    return this.displaySection ? "angle-down" : "angle-right";
  }

  get isSingleHeaderAction() {
    return this.args.headerActions?.length === 1;
  }

  get isMultipleHeaderActions() {
    return this.args.headerActions?.length > 1;
  }
}
