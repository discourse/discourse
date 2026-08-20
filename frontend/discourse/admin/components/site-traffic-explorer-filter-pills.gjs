import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import { countryName } from "discourse/admin/lib/format-country";
import { escapeExpression } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class SiteTrafficExplorerFilterPills extends Component {
  @action
  filterLabel(key) {
    return i18n(`admin.site_traffic_explorer.filters.${key}`);
  }

  @action
  removeLabel(filter) {
    if (filter.key === "traffic_type") {
      return i18n("admin.site_traffic_explorer.remove_traffic_type_filter", {
        value: filter.label,
      });
    }

    return i18n("admin.site_traffic_explorer.remove_filter", {
      filter: this.filterLabel(filter.key),
    });
  }

  @action
  filterDescription(filter) {
    const value =
      filter.key === "country" ? countryName(filter.value) : filter.label;

    return i18n("admin.site_traffic_explorer.filter_description", {
      filter: escapeExpression(this.filterLabel(filter.key)),
      value: escapeExpression(value),
    });
  }

  @action
  filterId(filter) {
    const suffix = filter.key === "traffic_type" ? `-${filter.value}` : "";
    return `site-traffic-filter-pill-${filter.key}${suffix}`;
  }

  <template>
    {{#if @filters.length}}
      <div
        class="site-traffic-explorer__filters"
        role="group"
        aria-label={{i18n "admin.site_traffic_explorer.active_filters"}}
      >
        {{#each @filters as |filter|}}
          <span
            class="site-traffic-explorer__filter-pill"
            id={{this.filterId filter}}
            data-test-site-traffic-filter-pill={{filter.key}}
          >
            <span>
              {{trustHTML (this.filterDescription filter)}}
            </span>
            <DButton
              class="btn-flat site-traffic-explorer__filter-remove"
              @icon="xmark"
              @translatedAriaLabel={{this.removeLabel filter}}
              @action={{fn @removeFilter filter.key filter.value}}
            />
          </span>
        {{/each}}
      </div>
    {{/if}}
  </template>
}
