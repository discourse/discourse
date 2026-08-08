import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class SiteTrafficFilterPills extends Component {
  @action
  filterLabel(key) {
    return i18n(`admin.site_traffic_explorer.filters.${key}`);
  }

  @action
  removeLabel(key) {
    return i18n("admin.site_traffic_explorer.remove_filter", {
      filter: this.filterLabel(key),
    });
  }

  <template>
    {{#if @filters.length}}
      <div
        class="site-traffic-explorer__filters"
        aria-label={{i18n "admin.site_traffic_explorer.active_filters"}}
      >
        {{#each @filters as |filter|}}
          <span
            class="site-traffic-explorer__filter-pill"
            data-test-site-traffic-filter-pill={{filter.key}}
          >
            <span>
              {{i18n
                "admin.site_traffic_explorer.filter_description"
                filter=(this.filterLabel filter.key)
                value=filter.label
              }}
            </span>
            <button
              type="button"
              class="btn-flat site-traffic-explorer__filter-remove"
              aria-label={{this.removeLabel filter.key}}
              {{on "click" (fn @removeFilter filter.key)}}
            >
              {{dIcon "xmark"}}
            </button>
          </span>
        {{/each}}
        <button
          type="button"
          class="btn-flat site-traffic-explorer__clear-filters"
          {{on "click" @clearFilters}}
        >
          {{i18n "admin.site_traffic_explorer.clear_filters"}}
        </button>
      </div>
    {{/if}}
  </template>
}
