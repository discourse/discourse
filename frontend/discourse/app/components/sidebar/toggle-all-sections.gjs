import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";

export default class ToggleAllSections extends Component {
  @service sidebarState;

  get collapsableSections() {
    return this.args.sections.filter((section) => !section.hideSectionHeader);
  }

  get allSectionsExpanded() {
    return this.collapsableSections.every((section) => {
      return (
        this.sidebarState.activeExpandedSections.has(section.sectionKey) ||
        !this.sidebarState.isSectionCollapsed(
          section.sectionKey,
          section.collapsedByDefault
        )
      );
    });
  }

  get title() {
    return this.allSectionsExpanded
      ? "sidebar.collapse_all_sections"
      : "sidebar.expand_all_sections";
  }

  get icon() {
    return this.allSectionsExpanded ? "angles-up" : "angles-down";
  }

  @action
  toggleAllSections() {
    const collapse = this.allSectionsExpanded;

    this.collapsableSections.forEach((section) => {
      if (collapse) {
        this.sidebarState.collapseSection(section.sectionKey);
      } else {
        this.sidebarState.expandSection(section.sectionKey);
      }
    });
  }

  <template>
    <DButton
      class="btn-transparent sidebar-toggle-all-sections"
      data-sidebar-keep-open
      @action={{this.toggleAllSections}}
      @icon={{this.icon}}
      @title={{this.title}}
    />
  </template>
}
