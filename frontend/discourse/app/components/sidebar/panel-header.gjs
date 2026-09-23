import Component from "@glimmer/component";
import { service } from "@ember/service";
import BackToForum from "discourse/components/sidebar/back-to-forum";
import Search from "discourse/components/sidebar/search";
import Filter from "./filter";
import FilterNoResults from "./filter-no-results";
import ToggleAllSections from "./toggle-all-sections";

export default class PanelHeader extends Component {
  @service sidebarState;

  get shouldDisplay() {
    return this.sidebarState.currentPanel.displayHeader;
  }

  get showFilter() {
    const minimum = this.sidebarState.currentPanel.filterableMinLinks;

    if (!minimum || this.sidebarState.filter) {
      return true;
    }

    const links = (this.args.sections ?? [])
      .filter((section) => section.displaySection)
      .reduce(
        (total, section) =>
          total +
          (section.links?.length ?? 0) +
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
          <ToggleAllSections @sections={{@sections}} />
        </div>
        <div class="sidebar-panel-header__row">
          <Search />
          {{#if this.showFilter}}
            <Filter />
          {{/if}}
        </div>
        <FilterNoResults @sections={{@sections}} />
      </div>
    {{/if}}
  </template>
}
