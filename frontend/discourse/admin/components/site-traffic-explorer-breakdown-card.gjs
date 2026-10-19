import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import SiteTrafficExplorerBreakdownModal from "discourse/admin/components/site-traffic-explorer-breakdown-modal";
import SiteTrafficExplorerBreakdownRow from "discourse/admin/components/site-traffic-explorer-breakdown-row";
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
        dimension: this.activeTab.dimension,
        rows: this.rows,
        rowLink: this.rowLink,
        selectedValues: this.rows
          .filter((row) => this.isSelected(row))
          .map((row) => row.value),
      },
    });

    if (result?.filterRows) {
      this.args.applyModalFilters(this.activeTab.filter, result.filterRows);
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
  toggleFilter(row) {
    this.args.toggleFilter(this.activeTab.filter, row);
  }

  @action
  isSelected(row) {
    return this.args.isFilterSelected(this.activeTab.filter, row.value);
  }

  <template>
    <section
      class="db-section__row-block"
      data-test-site-traffic-card={{@name}}
    >
      <div
        aria-label={{@title}}
        class="site-traffic-explorer__tabs"
        role="tablist"
      >
        {{#each @tabs as |tab index|}}
          <button
            aria-controls={{concat "site-traffic-" @name "-panel"}}
            aria-selected={{if (eq index this.activeTabIndex) "true" "false"}}
            class={{if (eq index this.activeTabIndex) "is-active"}}
            id={{concat "site-traffic-" @name "-tab-" tab.dimension}}
            role="tab"
            tabindex={{if (eq index this.activeTabIndex) "0" "-1"}}
            type="button"
            {{on "click" (fn this.selectTab index)}}
            {{on "keydown" (fn this.navigateTabs index)}}
          >
            {{tab.label}}
          </button>
        {{/each}}
      </div>

      <div
        aria-labelledby={{concat
          "site-traffic-"
          @name
          "-tab-"
          this.activeTab.dimension
        }}
        id={{concat "site-traffic-" @name "-panel"}}
        role="tabpanel"
      >
        <ul class="site-traffic-explorer__breakdown-list">
          {{#each this.visibleRows as |row index|}}
            <li>
              <SiteTrafficExplorerBreakdownRow
                @checked={{this.isSelected row}}
                @dimension={{this.activeTab.dimension}}
                @inputId={{concat "site-traffic-" @name "-filter-" index}}
                @onToggle={{fn this.toggleFilter row}}
                @row={{row}}
                @rowLink={{this.rowLink row}}
              />
            </li>
          {{else}}
            <li class="site-traffic-explorer__card-empty">
              {{i18n "admin.site_traffic_explorer.no_dimension_data"}}
            </li>
          {{/each}}
        </ul>
        {{#if this.canExpand}}
          <DButton
            class="btn-small btn-link --primary"
            @action={{this.openModal}}
            @label="admin.site_traffic_explorer.view_more"
          />
        {{/if}}
      </div>
    </section>
  </template>
}
