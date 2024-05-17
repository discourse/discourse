import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import i18n from "discourse-common/helpers/i18n";
import getURL from "discourse-common/lib/get-url";
import I18n from "discourse-i18n";

export default class FilterNoResults extends Component {
  @service sidebarState;

  /**
   * Component is rendered when panel is filtreable
   * Visibility is additionally controlled by CSS rule `.sidebar-section-wrapper + .sidebar-no-results`
   */
  get shouldDisplay() {
    return this.sidebarState.currentPanel.filterable;
  }

  get noResultsDescription() {
    const params = {
      filter: this.sidebarState.filter,
      settings_filter_url: getURL(
        `/admin/site_settings/category/all_results?filter=${this.sidebarState.filter}`
      ),
      user_list_filter_url: getURL(
        `/admin/users/list/active?username=${this.sidebarState.filter}`
      ),
    };
    return htmlSafe(I18n.t("sidebar.no_results.description", params));
  }

  <template>
    {{#if this.shouldDisplay}}
      <div class="sidebar-no-results">
        <h4 class="sidebar-no-results__title">{{i18n
            "sidebar.no_results.title"
          }}</h4>
        <p
          class="sidebar-no-results__description"
        >{{this.noResultsDescription}}</p>
      </div>
    {{/if}}
  </template>
}
