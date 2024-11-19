import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export default class FilterNoResults extends Component {
  @service sidebarState;

  get shouldDisplay() {
    return (
      this.sidebarState.currentPanel.filterable &&
      !!(this.args.sections?.length === 0)
    );
  }

  get noResultsDescription() {
    return this.sidebarState.currentPanel.filterNoResultsDescription(
      this.sidebarState.filter
    );
  }

  <template>
    {{#if this.shouldDisplay}}
      <div class="sidebar-no-results">
        <h4 class="sidebar-no-results__title">{{i18n
            "sidebar.no_results.title"
          }}</h4>
        {{#if this.noResultsDescription}}
          <p class="sidebar-no-results__description">
            {{this.noResultsDescription}}
          </p>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
