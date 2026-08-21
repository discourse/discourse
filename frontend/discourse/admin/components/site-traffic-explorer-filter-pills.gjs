import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import DMenu from "discourse/float-kit/components/d-menu";
import { gt, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const MAX_VISIBLE_FILTER_VALUES = 3;

export default class SiteTrafficExplorerFilterPills extends Component {
  get applyLabel() {
    const label = i18n("admin.site_traffic_explorer.apply");

    return this.args.pendingFilterCount > 0
      ? `${label} (${this.args.pendingFilterCount})`
      : label;
  }

  @action
  filterLabel(key) {
    return i18n(`admin.site_traffic_explorer.filters.${key}`);
  }

  @action
  filteringToLabel(filter) {
    return i18n(`admin.site_traffic_explorer.filtering_to.${filter.key}`, {
      count: filter.values.length,
    });
  }

  @action
  removeLabel(filter) {
    return i18n("admin.site_traffic_explorer.remove_filter", {
      filter: this.filterLabel(filter.key),
    });
  }

  @action
  visibleValues(filter) {
    return filter.values.slice(0, MAX_VISIBLE_FILTER_VALUES);
  }

  @action
  remainingCount(filter) {
    return Math.max(0, filter.values.length - MAX_VISIBLE_FILTER_VALUES);
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
      <div class="site-traffic-explorer__filter-controls">
        <div
          class="site-traffic-explorer__filters"
          role="group"
          aria-label={{i18n "admin.site_traffic_explorer.active_filters"}}
        >
          {{#each @filters key="key" as |filter|}}
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
                    {{this.filterLabel filter.key}}:
                    <span class="site-traffic-explorer__filter-pill-values">
                      {{~#each (this.visibleValues filter) as |value index|~}}
                        {{~if index ", "~}}<span
                          class="site-traffic-explorer__filter-pill-value"
                        >{{value.label}}</span>
                      {{~/each~}}
                    </span>
                    {{#if (gt (this.remainingCount filter) 0)}}
                      <span
                        class="site-traffic-explorer__filter-pill-remaining"
                      >+{{this.remainingCount filter}}</span>
                    {{/if}}
                    {{dIcon "angle-down"}}
                  </:trigger>
                  <:content>
                    <DDropdownMenu
                      class="site-traffic-explorer__filter-dropdown"
                      data-test-site-traffic-filter-dropdown
                      as |dropdown|
                    >
                      <dropdown.subheader>{{this.filteringToLabel
                          filter
                        }}</dropdown.subheader>

                      {{#each filter.values as |value|}}
                        <dropdown.item
                          data-test-site-traffic-filter-dropdown-value
                        >
                          <DButton
                            @suffixIcon="xmark"
                            @translatedLabel={{value.label}}
                            @translatedAriaLabel={{this.removeValueLabel value}}
                            @translatedTitle={{this.removeValueLabel value}}
                            @action={{fn this.removeFilterValue filter value}}
                          />
                        </dropdown.item>
                      {{/each}}

                      <dropdown.divider />

                      <dropdown.item>
                        <DButton
                          @label="admin.site_traffic_explorer.clear_all"
                          @action={{fn @clearFilter filter.key}}
                        />
                      </dropdown.item>
                    </DDropdownMenu>
                  </:content>
                </DMenu>
              {{else}}
                {{this.filterLabel filter.key}}:
                <span class="site-traffic-explorer__filter-pill-values">
                  {{#each filter.values as |value|}}
                    <strong>{{value.label}}</strong>
                  {{/each}}
                </span>
              {{/if}}
              <DButton
                class="btn-flat btn-small site-traffic-explorer__filter-remove"
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
              class="btn-transparent --primary"
              @label="admin.site_traffic_explorer.clear_all_filters"
              @action={{@clearAllFilters}}
            />
          {{/if}}

          {{#if @hasPendingFilters}}
            <DButton
              class="btn-primary site-traffic-explorer__filter-apply"
              @translatedAriaLabel={{this.applyLabel}}
              @action={{@applyFilters}}
              data-test-site-traffic-apply-filters
            >
              <span class="d-button-label">{{i18n
                  "admin.site_traffic_explorer.apply"
                }}</span>
              {{#if (gt @pendingFilterCount 0)}}
                <span
                  class="site-traffic-explorer__filter-apply-pending-count"
                >{{@pendingFilterCount}}</span>
              {{/if}}
            </DButton>
          {{/if}}
        </div>
      </div>
    {{/if}}
  </template>
}
