import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import i18n from "discourse-common/helpers/i18n";

export default class FilterNoResulsts extends Component {
  @service sidebarState;

  get shouldDisplay() {
    return this.sidebarState.currentPanel.filterable;
  }

  <template>
    {{#if this.shouldDisplay}}
      <div class="sidebar-no-results">
        <div class="sidebar-no-results__title">{{i18n
            "sidebar.no_results.title"
          }}</div>
        <div class="sidebar-no-results__description">{{i18n
            "sidebar.no_results.description"
            filter=this.sidebarState.filter
          }}</div>
      </div>
    {{/if}}
  </template>
}
