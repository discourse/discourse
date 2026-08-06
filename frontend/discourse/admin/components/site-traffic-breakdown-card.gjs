import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import SiteTrafficBreakdownModal from "discourse/admin/components/site-traffic-breakdown-modal";
import SiteTrafficDimensionLabel from "discourse/admin/components/site-traffic-dimension-label";
import { eq } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const CARD_ROW_LIMIT = 8;

export default class SiteTrafficBreakdownCard extends Component {
  @tracked activeTabIndex = 0;
  @tracked expanded = false;

  get activeTab() {
    return this.args.tabs[this.activeTabIndex] ?? this.args.tabs[0];
  }

  get rows() {
    return this.args.dimensions?.[this.activeTab.dimension] ?? [];
  }

  get visibleRows() {
    return this.rows.slice(0, CARD_ROW_LIMIT);
  }

  get canExpand() {
    return this.rows.length > CARD_ROW_LIMIT;
  }

  @action
  filterLabel(label) {
    return i18n("admin.site_traffic_explorer.filter_by", { label });
  }

  @action
  selectTab(index) {
    this.activeTabIndex = index;
  }

  @action
  navigateTabs(index, event) {
    let nextIndex;

    if (event.key === "ArrowLeft") {
      nextIndex = (index - 1 + this.args.tabs.length) % this.args.tabs.length;
    } else if (event.key === "ArrowRight") {
      nextIndex = (index + 1) % this.args.tabs.length;
    } else if (event.key === "Home") {
      nextIndex = 0;
    } else if (event.key === "End") {
      nextIndex = this.args.tabs.length - 1;
    } else {
      return;
    }

    event.preventDefault();
    const nextTab = event.currentTarget.parentElement.children[nextIndex];
    nextTab?.focus();
    this.selectTab(nextIndex);
  }

  @action
  openModal() {
    this.expanded = true;
  }

  @action
  closeModal() {
    this.expanded = false;
  }

  @action
  filter(row) {
    const filterKey = this.activeTab.filter;
    this.args.setFilter(filterKey, row);
    this.expanded = false;

    next(() => {
      document
        .querySelector(
          `[data-test-site-traffic-filter-pill='${filterKey}'] button`
        )
        ?.focus();
    });
  }

  <template>
    <section
      class="site-traffic-explorer__card"
      data-test-site-traffic-card={{@name}}
    >
      <div
        class="site-traffic-explorer__tabs"
        role="tablist"
        aria-label={{@title}}
      >
        {{#each @tabs as |tab index|}}
          <button
            type="button"
            role="tab"
            id={{concat "site-traffic-tab-" @name "-" tab.dimension}}
            aria-controls={{concat "site-traffic-panel-" @name}}
            aria-selected={{if (eq index this.activeTabIndex) "true" "false"}}
            tabindex={{if (eq index this.activeTabIndex) "0" "-1"}}
            class="site-traffic-explorer__tab
              {{if (eq index this.activeTabIndex) 'is-active'}}"
            {{on "click" (fn this.selectTab index)}}
            {{on "keydown" (fn this.navigateTabs index)}}
          >
            {{tab.label}}
          </button>
        {{/each}}
      </div>

      <div
        class="site-traffic-explorer__rows"
        role="tabpanel"
        id={{concat "site-traffic-panel-" @name}}
        aria-labelledby={{concat
          "site-traffic-tab-"
          @name
          "-"
          this.activeTab.dimension
        }}
      >
        {{#each this.visibleRows as |row|}}
          <div class="site-traffic-explorer__row" data-test-site-traffic-row>
            {{#if this.activeTab.link}}
              <a href={{row.value}} class="site-traffic-explorer__row-label">
                <SiteTrafficDimensionLabel
                  @dimension={{this.activeTab.dimension}}
                  @row={{row}}
                />
              </a>
            {{else}}
              <span class="site-traffic-explorer__row-label">
                <SiteTrafficDimensionLabel
                  @dimension={{this.activeTab.dimension}}
                  @row={{row}}
                />
              </span>
            {{/if}}
            <span
              class="site-traffic-explorer__row-count"
            >{{row.pageviews}}</span>
            <button
              type="button"
              class="btn-flat site-traffic-explorer__row-filter"
              aria-label={{this.filterLabel row.label}}
              {{on "click" (fn this.filter row)}}
            >
              {{dIcon "filter"}}
            </button>
          </div>
        {{else}}
          <p class="site-traffic-explorer__card-empty">
            {{i18n "admin.site_traffic_explorer.no_dimension_data"}}
          </p>
        {{/each}}
      </div>

      {{#if this.canExpand}}
        <button
          type="button"
          class="btn-flat site-traffic-explorer__view-more"
          {{on "click" this.openModal}}
        >
          {{i18n "admin.site_traffic_explorer.view_more"}}
        </button>
      {{/if}}
    </section>

    {{#if this.expanded}}
      <SiteTrafficBreakdownModal
        @title={{this.activeTab.label}}
        @dimension={{this.activeTab.dimension}}
        @link={{this.activeTab.link}}
        @rows={{this.rows}}
        @filter={{this.filter}}
        @close={{this.closeModal}}
      />
    {{/if}}
  </template>
}
