import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { next, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import SiteTrafficExplorerBreakdownModal from "discourse/admin/components/site-traffic-explorer-breakdown-modal";
import SiteTrafficExplorerDimensionLabel from "discourse/admin/components/site-traffic-explorer-dimension-label";
import SiteTrafficExplorerPageviewCount from "discourse/admin/components/site-traffic-explorer-pageview-count";
import { countryName } from "discourse/admin/lib/format-country";
import getURL from "discourse/lib/get-url";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const CARD_ROW_LIMIT = 8;

export default class SiteTrafficExplorerBreakdownCard extends Component {
  @service modal;

  @tracked activeTabIndex = 0;

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
  filterLabel(row) {
    const label =
      this.activeTab.dimension === "countries"
        ? countryName(row.value)
        : row.label;

    return i18n("admin.site_traffic_explorer.filter_by", {
      label,
      count: row.pageviews,
    });
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
    this.selectTab(nextIndex);
    schedule("afterRender", () => {
      document
        .getElementById(
          `site-traffic-${this.args.name}-tab-${this.activeTab.dimension}`
        )
        ?.focus();
    });
  }

  @action
  async openModal() {
    const result = await this.modal.show(SiteTrafficExplorerBreakdownModal, {
      model: {
        title: this.activeTab.label,
        columnLabel: this.activeTab.columnLabel,
        dimension: this.activeTab.dimension,
        rows: this.rows,
        rowLink: this.rowLink,
      },
    });

    if (result?.filterRow) {
      this.filter(result.filterRow);
    }
  }

  @action
  rowLink(row) {
    if (!row.value) {
      return null;
    }

    if (this.activeTab.dimension === "referrers") {
      return {
        href: `https://${row.value}`,
        rel: "noopener noreferrer nofollow ugc",
        target: "_blank",
      };
    }

    if (["top_urls", "entry_urls"].includes(this.activeTab.dimension)) {
      return {
        href: getURL(row.value),
        rel: "noopener noreferrer",
        target: "_blank",
      };
    }

    return null;
  }

  @action
  filter(row) {
    const filterKey = this.activeTab.filter;
    this.args.setFilter(filterKey, row);

    next(() => {
      document
        .querySelector(`#site-traffic-filter-pill-${filterKey} button`)
        ?.focus();
    });
  }

  <template>
    <section
      class="db-section__row-block site-traffic-explorer__card"
      data-test-site-traffic-card={{@name}}
    >
      <h2 class="sr-only">{{@title}}</h2>
      <div
        class="site-traffic-explorer__tabs"
        role="tablist"
        aria-label={{@title}}
      >
        {{#each @tabs as |tab index|}}
          <button
            type="button"
            role="tab"
            id={{concat "site-traffic-" @name "-tab-" tab.dimension}}
            aria-controls={{concat "site-traffic-" @name "-panel"}}
            aria-selected={{if (eq index this.activeTabIndex) "true" "false"}}
            tabindex={{if (eq index this.activeTabIndex) "0" "-1"}}
            class={{if (eq index this.activeTabIndex) "is-active"}}
            {{on "click" (fn this.selectTab index)}}
            {{on "keydown" (fn this.navigateTabs index)}}
          >
            {{tab.label}}
          </button>
        {{/each}}
      </div>

      <div
        role="tabpanel"
        id={{concat "site-traffic-" @name "-panel"}}
        aria-labelledby={{concat
          "site-traffic-"
          @name
          "-tab-"
          this.activeTab.dimension
        }}
      >
        <ul class="site-traffic-explorer__breakdown-list">
          {{#each this.visibleRows as |row|}}
            <li>
              {{#let (this.rowLink row) as |rowLink|}}
                {{#if rowLink}}
                  <span
                    class="site-traffic-explorer__row"
                    data-test-site-traffic-row
                  >
                    <a
                      href={{rowLink.href}}
                      rel={{rowLink.rel}}
                      target={{rowLink.target}}
                      class="site-traffic-explorer__row-link"
                    >
                      <SiteTrafficExplorerDimensionLabel
                        @dimension={{this.activeTab.dimension}}
                        @row={{row}}
                      />
                    </a>
                    <button
                      type="button"
                      class="site-traffic-explorer__row-filter-area"
                      aria-label={{this.filterLabel row}}
                      {{on "click" (fn this.filter row)}}
                    >
                      <SiteTrafficExplorerPageviewCount
                        @value={{row.pageviews}}
                        as |formattedValue|
                      >
                        <span class="site-traffic-explorer__row-count">
                          {{formattedValue}}
                        </span>
                      </SiteTrafficExplorerPageviewCount>
                    </button>
                  </span>
                {{else}}
                  <button
                    type="button"
                    class="site-traffic-explorer__row"
                    aria-label={{this.filterLabel row}}
                    data-test-site-traffic-row
                    {{on "click" (fn this.filter row)}}
                  >
                    <span class="site-traffic-explorer__row-label">
                      <SiteTrafficExplorerDimensionLabel
                        @dimension={{this.activeTab.dimension}}
                        @row={{row}}
                      />
                    </span>
                    <SiteTrafficExplorerPageviewCount
                      @value={{row.pageviews}}
                      as |formattedValue|
                    >
                      <span class="site-traffic-explorer__row-count">
                        {{formattedValue}}
                      </span>
                    </SiteTrafficExplorerPageviewCount>
                  </button>
                {{/if}}
              {{/let}}
            </li>
          {{else}}
            <li class="site-traffic-explorer__card-empty">
              {{i18n "admin.site_traffic_explorer.no_dimension_data"}}
            </li>
          {{/each}}
        </ul>
        {{#if this.canExpand}}
          <DButton
            class="site-traffic-explorer__view-more btn-flat"
            @action={{this.openModal}}
            @label="admin.site_traffic_explorer.view_more"
          />
        {{/if}}
      </div>
    </section>
  </template>
}
