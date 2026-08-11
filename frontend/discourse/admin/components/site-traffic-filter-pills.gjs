import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import { escapeExpression } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
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

  @action
  filterDescription(filter) {
    return i18n("admin.site_traffic_explorer.filter_description", {
      filter: escapeExpression(this.filterLabel(filter.key)),
      value: escapeExpression(filter.label),
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
            id={{concat "site-traffic-filter-pill-" filter.key}}
            data-test-site-traffic-filter-pill={{filter.key}}
          >
            <span>
              {{trustHTML (this.filterDescription filter)}}
            </span>
            <DButton
              class="btn-flat site-traffic-explorer__filter-remove"
              @icon="xmark"
              @translatedAriaLabel={{this.removeLabel filter.key}}
              @action={{fn @removeFilter filter.key}}
            />
          </span>
        {{/each}}
      </div>
    {{/if}}
  </template>
}
