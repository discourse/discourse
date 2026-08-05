import Component from "@glimmer/component";
import { assert } from "@ember/debug";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { countryFlag } from "discourse/admin/lib/format-country";
import getURL from "discourse/lib/get-url";
import { and, eq, gt, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const CARD_TABS = {
  sources: ["traffic_sources", "countries", "networks"],
  pages: ["top_urls", "entry_urls"],
  visitors: ["browsers", "ip_addresses"],
};

export default class SiteTrafficBreakdownCard extends Component {
  constructor(owner, args) {
    super(owner, args);
    assert("Site traffic card key is invalid", CARD_TABS[args.cardKey]);
    assert(
      "Site traffic card tabs are invalid",
      args.tabs.every((tab) => CARD_TABS[args.cardKey].includes(tab.key))
    );
    assert(
      "Site traffic active tab is invalid",
      CARD_TABS[args.cardKey].includes(args.activeTab)
    );
  }

  get rows() {
    return this.args.rows.slice(0, 8);
  }

  get activeTabLabel() {
    return this.args.tabs.find((tab) => tab.key === this.args.activeTab)?.label;
  }

  @action
  selectTab(tabKey) {
    this.args.onSelectTab(tabKey);
  }

  @action
  navigateTabs(event) {
    const currentIndex = this.args.tabs.findIndex(
      (tab) => tab.key === this.args.activeTab
    );
    let nextIndex;

    if (event.key === "ArrowRight") {
      nextIndex = (currentIndex + 1) % this.args.tabs.length;
    } else if (event.key === "ArrowLeft") {
      nextIndex =
        (currentIndex - 1 + this.args.tabs.length) % this.args.tabs.length;
    } else if (event.key === "Home") {
      nextIndex = 0;
    } else if (event.key === "End") {
      nextIndex = this.args.tabs.length - 1;
    } else {
      return;
    }

    event.preventDefault();
    const nextTabKey = this.args.tabs[nextIndex].key;
    this.args.onSelectTab(nextTabKey);
    schedule("afterRender", () => {
      document
        .getElementById(`site-traffic-${this.args.cardKey}-tab-${nextTabKey}`)
        ?.focus();
    });
  }

  <template>
    <section class="site-traffic-detail__card" data-test-breakdown={{@cardKey}}>
      <h2 class="sr-only">{{@title}}</h2>
      <div
        class="site-traffic-detail__tabs"
        role="tablist"
        aria-label={{@title}}
      >
        {{#each @tabs as |tab|}}
          <button
            id="site-traffic-{{@cardKey}}-tab-{{tab.key}}"
            type="button"
            role="tab"
            data-site-traffic-breakdown-tab={{tab.key}}
            aria-controls="site-traffic-{{@cardKey}}-panel"
            aria-selected={{concat (if (eq @activeTab tab.key) "true" "false")}}
            tabindex={{if (eq @activeTab tab.key) "0" "-1"}}
            class={{if (eq @activeTab tab.key) "is-active"}}
            {{on "click" (fn this.selectTab tab.key)}}
            {{on "keydown" this.navigateTabs}}
          >
            {{tab.label}}
          </button>
        {{/each}}
      </div>
      <div
        id="site-traffic-{{@cardKey}}-panel"
        role="tabpanel"
        aria-labelledby="site-traffic-{{@cardKey}}-tab-{{@activeTab}}"
      >
        <ul class="site-traffic-detail__breakdown-list">
          {{#each this.rows as |row|}}
            <li>
              {{#if
                (and
                  row.value
                  (or (eq @activeTab "top_urls") (eq @activeTab "entry_urls"))
                )
              }}
                <span class="site-traffic-detail__row" data-test-breakdown-row>
                  <a
                    href={{getURL row.value}}
                    class="site-traffic-detail__row-link"
                    data-auto-route="true"
                    data-test-url-link
                  >{{row.displayLabel}}</a>
                  {{#if row.filterable}}
                    <button
                      type="button"
                      class="site-traffic-detail__row-filter-area"
                      aria-label={{i18n
                        "admin.dashboard.site_traffic.details.filter_row"
                        value=row.displayLabel
                      }}
                      title={{i18n
                        "admin.dashboard.site_traffic.details.filter_row"
                        value=row.displayLabel
                      }}
                      data-test-url-filter-area
                      {{on
                        "click"
                        (fn @onApplyFilter @filterDimension row.value)
                      }}
                    >
                      <span class="site-traffic-detail__row-count">
                        {{row.formattedPageviews}}
                      </span>
                    </button>
                  {{else}}
                    <span class="site-traffic-detail__row-count">
                      {{row.formattedPageviews}}
                    </span>
                  {{/if}}
                </span>
              {{else if row.filterable}}
                <button
                  type="button"
                  class="site-traffic-detail__row"
                  data-test-breakdown-row
                  {{on "click" (fn @onApplyFilter @filterDimension row.value)}}
                >
                  <span>
                    {{#if (eq @activeTab "countries")}}
                      <span aria-hidden="true">{{countryFlag row.value}}</span>
                    {{/if}}
                    {{#if row.icon}}
                      {{dIcon
                        row.icon
                        class="site-traffic-detail__browser-icon"
                      }}
                    {{/if}}
                    {{row.displayLabel}}
                  </span>
                  <span class="site-traffic-detail__row-count">
                    {{row.formattedPageviews}}
                  </span>
                </button>
              {{else}}
                <span class="site-traffic-detail__row" data-test-breakdown-row>
                  <span>
                    {{#if (eq @activeTab "countries")}}
                      <span aria-hidden="true">{{countryFlag row.value}}</span>
                    {{/if}}
                    {{#if row.icon}}
                      {{dIcon
                        row.icon
                        class="site-traffic-detail__browser-icon"
                      }}
                    {{/if}}
                    {{row.displayLabel}}
                  </span>
                  <span class="site-traffic-detail__row-count">
                    {{row.formattedPageviews}}
                  </span>
                </span>
              {{/if}}
            </li>
          {{/each}}
        </ul>
        {{#if (gt @rows.length 8)}}
          <DButton
            @label="admin.dashboard.site_traffic.details.view_more"
            @action={{fn @onViewMore @activeTab this.activeTabLabel @rows}}
            class="site-traffic-detail__view-more btn-flat"
          />
        {{/if}}
      </div>
    </section>
  </template>
}
