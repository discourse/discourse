import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { bind } from "discourse-common/utils/decorators";

export default class SidebarSection extends Component {
  @service keyValueStore;
  @service sidebarState;

  sidebarSectionContentID = `sidebar-section-content-${this.args.sectionName}`;
  collapsedSidebarSectionKey = `sidebar-section-${this.args.sectionName}-collapsed`;

  get isCollapsed() {
    if (!this.args.collapsable) {
      return false;
    }
    if (
      this.keyValueStore.getItem(this.collapsedSidebarSectionKey) === undefined
    ) {
      return this.args.collapsedByDefault;
    }
    return (
      this.keyValueStore.getItem(this.collapsedSidebarSectionKey) === "true"
    );
  }

  @bind
  setExpandedState() {
    if (this.isCollapsed) {
      this.sidebarState.collapseSection(this.args.sectionName);
    } else {
      this.sidebarState.expandSection(this.args.sectionName);
    }
  }

  get displaySectionContent() {
    return !this.sidebarState.collapsedSections.has(
      this.collapsedSidebarSectionKey
    );
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.args.willDestroy?.();
  }

  @action
  toggleSectionDisplay() {
    if (this.displaySectionContent) {
      this.sidebarState.collapseSection(this.args.sectionName);
    } else {
      this.sidebarState.expandSection(this.args.sectionName);
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
