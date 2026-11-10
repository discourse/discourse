import Component from "@glimmer/component";
import { service } from "@ember/service";
import BackToForum from "discourse/components/sidebar/back-to-forum";
import Search from "discourse/components/sidebar/search";
import Filter from "./filter.gjs";
import FilterNoResults from "./filter-no-results.gjs";
import ToggleAllSections from "./toggle-all-sections.gjs";

function visibleSections(sections) {
  return sections.flatMap((section) =>
    section.displaySection === false
      ? []
      : [section, ...visibleSections(section.childSections)]
  );
}

export default class PanelHeader extends Component {
  @service sidebarState;

  get shouldDisplay() {
    return this.sidebarState.currentPanel.displayHeader;
  }

  get sections() {
    return visibleSections(this.args.sections);
  }

  get showFilter() {
    const minimum = this.sidebarState.currentPanel.filterableMinLinks;

    if (!minimum || this.sidebarState.filter) {
      return true;
    }

    const links = this.sections.reduce(
      (total, section) =>
        total +
        section.sidebarItems.filter((item) => item.type === "link").length +
        (section.moreLinks?.length ?? 0),
      0
    );

    return links >= minimum;
  }

  <template>
    {{#if this.shouldDisplay}}
      <div class="sidebar-panel-header">
        <div class="sidebar-panel-header__row">
          <BackToForum
            @href={{this.sidebarState.currentPanel.backLink.href}}
            @label={{this.sidebarState.currentPanel.backLink.label}}
          />
          <ToggleAllSections @sections={{this.sections}} />
        </div>
        <div class="sidebar-panel-header__row">
          <Search />
          {{#if this.showFilter}}
            <Filter />
          {{/if}}
        </div>
        <FilterNoResults @sections={{@filteredSections}} />
      </div>
    {{/if}}
  </template>
}
