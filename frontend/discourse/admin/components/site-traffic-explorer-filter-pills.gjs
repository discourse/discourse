import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { trustHTML } from "@ember/template";
import fitSiteTrafficFilterPill from "discourse/admin/modifiers/fit-site-traffic-filter-pill";
import DMenu from "discourse/float-kit/components/d-menu";
import { escapeExpression } from "discourse/lib/utilities";
import { gt, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const MAX_VISIBLE_FILTER_VALUES = 3;

export default class SiteTrafficExplorerFilterPills extends Component {
  @tracked visibleValueCounts = {};

  @action
  filterLabel(key) {
    return i18n(`admin.site_traffic_explorer.filters.${key}`);
  }

  @action
  filteringToLabel(filter) {
    return i18n("admin.site_traffic_explorer.filtering_to", {
      count: filter.values.length,
      filter: i18n(`admin.site_traffic_explorer.filter_plurals.${filter.key}`),
    });
  }

  @action
  maximumVisibleCount(filter) {
    return Math.min(filter.values.length, MAX_VISIBLE_FILTER_VALUES);
  }

  @action
  visibleValueCount(filter) {
    return Math.min(
      filter.values.length,
      this.visibleValueCounts[filter.key] ?? this.maximumVisibleCount(filter)
    );
  }

  @action
  setVisibleValueCount(key, count) {
    if (this.visibleValueCounts[key] === count) {
      return;
    }

    this.visibleValueCounts = { ...this.visibleValueCounts, [key]: count };
  }

  @action
  filterSignature(filter) {
    return filter.values.map((value) => value.label).join("\0");
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
      value: `<strong class="site-traffic-explorer__filter-pill-values">${escapeExpression(filter.values[0].label)}</strong>`,
    });
  }

  @action
  groupedFilterDescription(filter, visibleCount) {
    const visibleValues = filter.values
      .slice(0, visibleCount)
      .map((value) => `<strong>${escapeExpression(value.label)}</strong>`)
      .join(i18n("admin.site_traffic_explorer.filter_value_separator"));
    const remainingCount = filter.values.length - visibleCount;
    const values = `<span class="site-traffic-explorer__filter-pill-values">${visibleValues}</span>`;

    return i18n("admin.site_traffic_explorer.grouped_filter_description", {
      filter: escapeExpression(this.filterLabel(filter.key)),
      values,
      remaining:
        remainingCount > 0
          ? `<span class="site-traffic-explorer__filter-pill-remaining">${i18n(
              "admin.site_traffic_explorer.additional_filter_values",
              { count: remainingCount }
            )}</span>`
          : "",
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

  <template>
    {{#if (or (gt @filters.length 0) @hasPendingFilters)}}
      <div class="site-traffic-explorer__filter-slot">
        <div
          class="site-traffic-explorer__filter-controls"
          role="group"
          aria-label={{i18n "admin.site_traffic_explorer.active_filters"}}
        >
          <div class="site-traffic-explorer__filters">
            {{#each @filters key="key" as |filter|}}
              <span
                class="site-traffic-explorer__filter-pill
                  {{if filter.pending 'is-pending'}}"
                id={{this.filterId filter}}
                data-test-site-traffic-filter-pill={{filter.key}}
                {{fitSiteTrafficFilterPill
                  filter.key
                  (this.maximumVisibleCount filter)
                  (this.filterSignature filter)
                  this.setVisibleValueCount
                }}
              >
                {{#if (gt filter.values.length 1)}}
                  <DMenu
                    @identifier={{this.filterId filter}}
                    @inline={{true}}
                    @title={{this.filterLabel filter.key}}
                  >
                    <:trigger>
                      <span
                        class="site-traffic-explorer__filter-pill-label"
                      >{{trustHTML
                          (this.groupedFilterDescription
                            filter (this.visibleValueCount filter)
                          )
                        }}</span>
                      {{dIcon "angle-down"}}
                    </:trigger>
                    <:content>
                      <div
                        class="site-traffic-explorer__filter-dropdown"
                        data-test-site-traffic-filter-dropdown
                      >
                        <div
                          class="site-traffic-explorer__filter-dropdown-title"
                        >{{this.filteringToLabel filter}}</div>
                        <ul>
                          {{#each filter.values as |value|}}
                            <li data-test-site-traffic-filter-dropdown-value>
                              <span
                                class="site-traffic-explorer__filter-dropdown-value"
                                title={{value.label}}
                              >{{value.label}}</span>
                              <DButton
                                class="btn-flat"
                                @icon="xmark"
                                @translatedAriaLabel={{this.removeValueLabel
                                  value
                                }}
                                @translatedTitle={{this.removeValueLabel value}}
                                @action={{fn
                                  this.removeFilterValue
                                  filter
                                  value
                                }}
                              />
                            </li>
                          {{/each}}
                        </ul>
                        <DButton
                          class="btn-flat site-traffic-explorer__filter-dropdown-clear"
                          @label="admin.site_traffic_explorer.clear_all"
                          @action={{fn @clearFilter filter.key}}
                        />
                      </div>
                    </:content>
                  </DMenu>
                {{else}}
                  <span
                    class="site-traffic-explorer__filter-pill-label"
                  >{{trustHTML (this.filterDescription filter)}}</span>
                {{/if}}
                <DButton
                  class="btn-flat site-traffic-explorer__filter-remove"
                  @icon="xmark"
                  @translatedAriaLabel={{this.removeLabel filter}}
                  @action={{fn @clearFilter filter.key}}
                />
              </span>
            {{/each}}
          </div>

          <div class="site-traffic-explorer__filter-actions">
            {{#if (gt @filters.length 0)}}
              <DButton
                class="btn-flat"
                @label="admin.site_traffic_explorer.clear_all_filters"
                @action={{@clearAllFilters}}
              />
            {{/if}}

            {{#if @hasPendingFilters}}
              <button
                type="button"
                class="btn btn-primary site-traffic-explorer__apply-filters"
                data-test-site-traffic-apply-filters
                {{on "click" @applyFilters}}
              >
                <span>{{i18n "admin.site_traffic_explorer.apply"}}</span>
                {{#if (gt @pendingFilterCount 0)}}
                  <span
                    data-test-site-traffic-apply-count
                  >({{@pendingFilterCount}})</span>
                {{/if}}
              </button>
            {{/if}}
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
