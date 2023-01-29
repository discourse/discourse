import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class SidebarSection extends Component {
  @service keyValueStore;

  @tracked displaySectionContent;
  sidebarSectionContentID = `sidebar-section-content-${this.args.sectionName}`;
  collapsedSidebarSectionKey = `sidebar-section-${this.args.sectionName}-collapsed`;

  constructor() {
    super(...arguments);

    if (this.args.collapsable) {
      this.displaySectionContent =
        this.keyValueStore.getItem(this.collapsedSidebarSectionKey) ===
        undefined
          ? true
          : false;
    } else {
      this.displaySectionContent = true;
    }
  }

  willDestroy() {
    if (this.args.willDestroy) {
      this.args.willDestroy();
    }
  }

  @action
  toggleSectionDisplay() {
    this.displaySectionContent = !this.displaySectionContent;

    if (this.displaySectionContent) {
      this.keyValueStore.remove(this.collapsedSidebarSectionKey);
    } else {
      this.keyValueStore.setItem(this.collapsedSidebarSectionKey, true);
    }

    // remove focus from the toggle, but only on click
    if (!event.key) {
      document.activeElement.blur();
    }
  }

  @action
  handleMultipleHeaderActions(id) {
    this.args.headerActions
      .find((headerAction) => headerAction.id === id)
      .action();
  }

  get headerCaretIcon() {
    return this.displaySectionContent ? "angle-down" : "angle-right";
  }

  get isSingleHeaderAction() {
    return this.args.headerActions?.length === 1;
  }

  get isMultipleHeaderActions() {
    return this.args.headerActions?.length > 1;
  }

  get displaySection() {
    if (this.args.displaySection === undefined) {
      return true;
    }

    return this.args.displaySection;
  }
}
