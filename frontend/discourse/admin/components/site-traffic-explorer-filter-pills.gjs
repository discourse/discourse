import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { trustHTML } from "@ember/template";
import DMenu from "discourse/float-kit/components/d-menu";
import { escapeExpression } from "discourse/lib/utilities";
import { gt, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class SiteTrafficExplorerFilterPills extends Component {
  @action
  filterLabel(key) {
    return i18n(`admin.site_traffic_explorer.filters.${key}`);
  }

  @action
  removeLabel(filter) {
    return i18n("admin.site_traffic_explorer.remove_filter", {
      filter: this.filterLabel(filter.key),
    });
  }

  @action
  filterDescription(filter) {
    return i18n("admin.site_traffic_explorer.filter_description", {
      filter: escapeExpression(this.filterLabel(filter.key)),
      value: escapeExpression(filter.values[0].label),
    });
  }

  @action
  groupedFilterDescription(filter) {
    return i18n("admin.site_traffic_explorer.grouped_filter_description", {
      filter: escapeExpression(this.filterLabel(filter.key)),
      value: escapeExpression(filter.values[0].label),
      count: filter.values.length - 1,
    });
  }

  @action
  removeValueLabel(value) {
    return i18n("admin.site_traffic_explorer.remove_filter_value", {
      value: value.label,
    });
  }

  @action
  removeFilterValue(filter, value) {
    this.args.removeFilterValue(filter.key, value.value);

    schedule("afterRender", () => {
      const nextRemoveButton = document.querySelector(
        "[data-test-site-traffic-filter-dropdown-value] button"
      );
      const pillRemoveButton = document.querySelector(
        `#${this.filterId(filter)} .site-traffic-explorer__filter-remove`
      );
      (nextRemoveButton ?? pillRemoveButton)?.focus();
    });
  }

  @action
  filterId(filter) {
    return `site-traffic-filter-pill-${filter.key}`;
  }

  @action
  applyLabel() {
    if (this.args.pendingFilterCount === 0) {
      return i18n("admin.site_traffic_explorer.apply");
    }

    return i18n("admin.site_traffic_explorer.apply_with_count", {
      count: this.args.pendingFilterCount,
    });
  }

  <template>
    {{#if (or (gt @filters.length 0) @hasPendingFilters)}}
      <div
        class="site-traffic-explorer__filter-controls"
        role="group"
        aria-label={{i18n "admin.site_traffic_explorer.active_filters"}}
      >
        <div class="site-traffic-explorer__filters">
          {{#each @filters as |filter|}}
            <span
              class="site-traffic-explorer__filter-pill
                {{if filter.pending 'is-pending'}}"
              id={{this.filterId filter}}
              data-test-site-traffic-filter-pill={{filter.key}}
            >
              {{#if (gt filter.values.length 1)}}
                <DMenu
                  @identifier={{this.filterId filter}}
                  @inline={{true}}
                  @title={{this.filterLabel filter.key}}
                >
                  <:trigger>
                    <span>{{trustHTML
                        (this.groupedFilterDescription filter)
                      }}</span>
                    {{dIcon "angle-down"}}
                  </:trigger>
                  <:content>
                    <div
                      class="site-traffic-explorer__filter-dropdown"
                      data-test-site-traffic-filter-dropdown
                    >
                      <strong>{{i18n
                          "admin.site_traffic_explorer.selected_filter_values"
                          filter=(this.filterLabel filter.key)
                        }}</strong>
                      <ul>
                        {{#each filter.values as |value|}}
                          <li data-test-site-traffic-filter-dropdown-value>
                            <span>{{value.label}}</span>
                            <button
                              type="button"
                              class="btn btn-flat"
                              aria-label={{this.removeValueLabel value}}
                              title={{this.removeValueLabel value}}
                              {{on
                                "click"
                                (fn this.removeFilterValue filter value)
                              }}
                            >
                              {{dIcon "xmark"}}
                            </button>
                          </li>
                        {{/each}}
                      </ul>
                      <DButton
                        class="btn-flat"
                        @label="admin.site_traffic_explorer.clear_all"
                        @action={{fn @clearFilter filter.key}}
                      />
                    </div>
                  </:content>
                </DMenu>
              {{else}}
                <span>{{trustHTML (this.filterDescription filter)}}</span>
              {{/if}}
              <button
                type="button"
                class="btn btn-flat site-traffic-explorer__filter-remove"
                aria-label={{this.removeLabel filter}}
                {{on "click" (fn @clearFilter filter.key)}}
              >
                {{dIcon "xmark"}}
              </button>
            </span>
          {{/each}}
        </div>

        {{#if @hasPendingFilters}}
          <DButton
            class="btn-primary site-traffic-explorer__apply-filters"
            data-test-site-traffic-apply-filters
            @translatedLabel={{this.applyLabel}}
            @action={{@applyFilters}}
          />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
