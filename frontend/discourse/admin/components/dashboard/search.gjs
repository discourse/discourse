import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DashboardSection from "discourse/admin/components/dashboard/section";
import {
  formatDashboardHeadlinePeriod,
  formatDeltaPercent,
} from "discourse/admin/lib/dashboard-format";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import dBasePath from "discourse/ui-kit/helpers/d-base-path";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import I18n, { i18n } from "discourse-i18n";

function formatCount(value) {
  return I18n.toNumber(value, { precision: 0 });
}

function badgeLabel(status) {
  return i18n(`admin.dashboard.sections.search.content_gaps.badge.${status}`);
}

function badgeTooltip(status) {
  return i18n(
    `admin.dashboard.sections.search.content_gaps.badge.${status}_tooltip`
  );
}

export default class DashboardSearch extends Component {
  @service currentUser;

  get loggingDisabled() {
    return this.args.search?.logging_enabled === false;
  }

  get headline() {
    const totalSearches = this.args.search.kpis.total_searches;
    const noResultRate = this.args.search.kpis.no_result_rate;

    if (
      totalSearches.value === 0 &&
      totalSearches.previous_value === 0 &&
      noResultRate.value == null
    ) {
      return {
        title: i18n("admin.dashboard.sections.search.headline.no_data.title"),
        summary: i18n(
          "admin.dashboard.sections.search.headline.no_data.summary"
        ),
      };
    }

    const searchesDirection = this.#direction(
      totalSearches,
      totalSearches.percent_change
    );
    const noResultDirection = this.#direction(
      noResultRate,
      noResultRate.point_change
    );
    const period = formatDashboardHeadlinePeriod(this.args.period);
    const prefix = "admin.dashboard.sections.search.headline";
    const scenario = `${searchesDirection}_${noResultDirection}`;

    return {
      title: i18n(`${prefix}.${scenario}.title`, { period }),
      summary: i18n(`${prefix}.${scenario}.summary`),
    };
  }

  #direction(kpi, change) {
    if (kpi.value == null) {
      return "unavailable";
    }

    if (kpi.previous_value == null || kpi.previous_value === 0) {
      return kpi.value > 0 ? "up" : "flat";
    }

    if (change > 0) {
      return "up";
    } else if (change < 0) {
      return "down";
    }

    return "flat";
  }

  get totalSearchesValue() {
    return formatCount(this.args.search.kpis.total_searches.value);
  }

  get totalSearchesDelta() {
    const change = this.args.search.kpis.total_searches.percent_change;

    if (change == null) {
      return null;
    }

    return {
      text: formatDeltaPercent(change),
      className: change > 0 ? "--pos" : "--neg",
    };
  }

  get noResultRateValue() {
    const value = this.args.search.kpis.no_result_rate.value;
    return value == null ? "—" : `${formatCount(value)}%`;
  }

  get noResultRateDelta() {
    const change = this.args.search.kpis.no_result_rate.point_change;

    if (change == null) {
      return null;
    }

    return {
      text: formatDeltaPercent(change),
      className: change > 0 ? "--neg" : "--pos",
    };
  }

  get rateExceedsThreshold() {
    return this.args.search.kpis.no_result_rate.exceeds_threshold;
  }

  get trendingTermPeriod() {
    if (this.args.period === "custom") {
      return "all";
    }

    return this.args.search.trending_period;
  }

  <template>
    <DashboardSection
      @title={{i18n "admin.dashboard.sections.search.title"}}
      @startDate={{@startDate}}
      @endDate={{@endDate}}
      ...attributes
    >
      {{#if @fetchError}}
        <div class="db-section__error" role="alert">
          {{i18n "admin.dashboard.sections.search.fetch_error"}}
        </div>
      {{else if this.loggingDisabled}}
        <p class="db-section__callout">
          {{#if this.currentUser.admin}}
            {{trustHTML
              (i18n
                "admin.dashboard.sections.search.logging_disabled"
                basePath=(dBasePath)
              )
            }}
          {{else}}
            {{i18n
              "admin.dashboard.sections.search.logging_disabled_moderator"
            }}
          {{/if}}
        </p>
      {{else if @search}}
        {{#if this.headline}}
          <div class="db-section__subheader">
            <div class="db-section__subintro">
              <h3>{{this.headline.title}}</h3>
              <p>{{this.headline.summary}}</p>
            </div>

            <div class="db-section__metrics">
              <div
                class="db-section__metric"
                data-test-search-kpi="total_searches"
              >
                <div class="db-section__metric-number">
                  {{this.totalSearchesValue}}
                </div>
                <div class="db-section__metric-label">
                  {{i18n
                    "admin.dashboard.sections.search.kpi.total_searches.label"
                  }}
                  <DTooltip
                    class="db-section__info"
                    @identifier="search-total-searches-tooltip"
                    @icon="far-circle-question"
                  >
                    <:content>
                      {{i18n
                        "admin.dashboard.sections.search.kpi.total_searches.tooltip"
                      }}
                    </:content>
                  </DTooltip>
                </div>
                {{#if this.totalSearchesDelta}}
                  <div
                    class="db-delta {{this.totalSearchesDelta.className}}"
                  >{{this.totalSearchesDelta.text}}</div>
                {{/if}}
              </div>

              <div
                class="db-section__metric"
                data-test-search-kpi="no_result_rate"
              >
                <div
                  class={{dConcatClass
                    "db-section__metric-number"
                    (if this.rateExceedsThreshold "--neg")
                  }}
                >
                  {{this.noResultRateValue}}
                </div>
                <div class="db-section__metric-label">
                  {{i18n
                    "admin.dashboard.sections.search.kpi.no_result_rate.label"
                  }}
                  <DTooltip
                    class="db-section__info"
                    @identifier="search-no-result-rate-tooltip"
                    @icon="far-circle-question"
                  >
                    <:content>
                      {{i18n
                        "admin.dashboard.sections.search.kpi.no_result_rate.tooltip"
                      }}
                    </:content>
                  </DTooltip>
                </div>
                {{#if this.noResultRateDelta}}
                  <div
                    class="db-delta {{this.noResultRateDelta.className}}"
                  >{{this.noResultRateDelta.text}}</div>
                {{/if}}
              </div>
            </div>
          </div>
        {{/if}}

        <div class="db-section__row">
          <div class="db-section__row-block">
            <h3 class="db-section__row-block-title">
              {{i18n "admin.dashboard.sections.search.trending.title"}}
              <DTooltip
                class="db-section__info"
                @identifier="search-trending-tooltip"
                @icon="far-circle-question"
              >
                <:content>
                  {{i18n "admin.dashboard.sections.search.trending.tooltip"}}
                </:content>
              </DTooltip>
            </h3>
            {{#if @search.trending.length}}
              <table class="db-search-table">
                <thead>
                  <tr>
                    <th>{{i18n
                        "admin.dashboard.sections.search.table.term"
                      }}</th>
                    <th class="db-search-table__col-number">
                      {{i18n "admin.dashboard.sections.search.table.searches"}}
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {{#each @search.trending as |row|}}
                    <tr data-test-search-term-row>
                      <td>
                        <LinkTo
                          @route="adminSearchLogs.term"
                          @query={{hash
                            term=row.term
                            period=this.trendingTermPeriod
                            searchType="non_staff_only"
                          }}
                          title={{row.term}}
                        >
                          {{row.term}}
                        </LinkTo>
                      </td>
                      <td class="db-search-table__cell-number">
                        {{formatCount row.searches}}
                      </td>
                    </tr>
                  {{/each}}
                </tbody>
              </table>
            {{else}}
              <p class="db-search-table__empty">
                {{i18n "admin.dashboard.sections.search.trending.empty"}}
              </p>
            {{/if}}
          </div>

          <div class="db-section__row-block">
            <h3 class="db-section__row-block-title">
              {{i18n "admin.dashboard.sections.search.content_gaps.title"}}
            </h3>
            {{#if @search.content_gaps.length}}
              <table class="db-search-table">
                <thead>
                  <tr>
                    <th>{{i18n
                        "admin.dashboard.sections.search.table.term"
                      }}</th>
                    <th class="db-search-table__col-status">{{i18n
                        "admin.dashboard.sections.search.table.status"
                      }}</th>
                    <th class="db-search-table__col-number">
                      {{i18n "admin.dashboard.sections.search.table.searches"}}
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {{#each @search.content_gaps as |row|}}
                    <tr data-test-search-term-row>
                      <td>
                        <LinkTo
                          @route="full-page-search"
                          @query={{hash q=row.term}}
                          title={{row.term}}
                        >
                          {{row.term}}
                        </LinkTo>
                      </td>
                      <td>
                        <DTooltip
                          class="db-pill --neg"
                          @identifier="search-gap-badge-tooltip"
                        >
                          <:trigger>{{badgeLabel row.status}}</:trigger>
                          <:content>{{badgeTooltip row.status}}</:content>
                        </DTooltip>
                      </td>
                      <td class="db-search-table__cell-number">
                        {{formatCount row.searches}}
                      </td>
                    </tr>
                  {{/each}}
                </tbody>
              </table>
            {{else}}
              <p class="db-search-table__empty">
                {{i18n "admin.dashboard.sections.search.content_gaps.empty"}}
              </p>
            {{/if}}
          </div>
        </div>
      {{/if}}
    </DashboardSection>
  </template>
}
