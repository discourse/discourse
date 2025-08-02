import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { getCollapsedSidebarSectionKey } from "discourse/lib/sidebar/helpers";

export default class ToggleAllSections extends Component {
  @service sidebarState;
  @service keyValueStore;

  get collapsableSections() {
    return this.args.sections.filter(
      (section) => section.displaySection && !section.hideSectionHeader
    );
  }

  get allSectionsExpanded() {
    return this.collapsableSections.every((section) => {
      return !this.sidebarState.collapsedSections.has(
        getCollapsedSidebarSectionKey(section.name)
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
        this.sidebarState.collapseSection(section.name);
      } else {
        this.sidebarState.expandSection(section.name);
      }
    });
  }

  <template>
    <DButton
      @action={{this.toggleAllSections}}
      @icon={{this.icon}}
      @title={{this.title}}
      class="btn-transparent sidebar-toggle-all-sections"
    />
  </template>
}
