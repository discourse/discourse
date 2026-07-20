import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import AdminReportStackedChart from "discourse/admin/components/admin-report-stacked-chart";
import { countryFlag, countryName } from "discourse/admin/lib/format-country";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { ajax } from "discourse/lib/ajax";
import { formatMinutesSeconds } from "discourse/lib/formatter";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDateTimeInputRange from "discourse/ui-kit/d-date-time-input-range";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import I18n, { i18n } from "discourse-i18n";

const DIMENSION_LABELS = {
  normalized_url: "admin.browser_traffic.dimensions.url",
  normalized_referrer: "admin.browser_traffic.dimensions.traffic_source",
  country_code: "admin.browser_traffic.dimensions.country",
  asn: "admin.browser_traffic.dimensions.network",
  ip_address: "admin.browser_traffic.dimensions.ip_address",
  browser: "admin.browser_traffic.dimensions.browser",
};

const FILTER_QUERY_PARAMS = {
  normalized_url: "url",
  normalized_referrer: "source",
  country_code: "country",
  asn: "network",
  ip_address: "ip",
  browser: "browser",
};

export default class BrowserTrafficExplorer extends Component {
  @service a11y;
  @service router;

  @tracked data;
  @tracked errorType;
  @tracked filters = {};
  @tracked loading = false;
  @tracked sourceFacet = "normalized_referrer";
  @tracked clientFacet = "browser";
  @tracked startDate;
  @tracked endDate;

  formatCount = (value) => {
    if (value >= 1_000_000) {
      const formatted = I18n.toNumber(value / 1_000_000, { precision: 1 });
      return `${formatted.replace(/[,.]0$/, "")}M`;
    }

    if (value >= 1_000) {
      return `${I18n.toNumber(Math.round(value / 1_000), { precision: 0 })}k`;
    }

    return I18n.toNumber(value || 0, { precision: 0 });
  };

  rowsFor = (facet) => this.data?.facets[facet] || [];

  valueLabel = (facet, row) => {
    if (row.value === null || row.value === undefined) {
      return i18n(`admin.browser_traffic.null_values.${facet}`);
    }

    if (facet === "country_code") {
      return countryName(row.value);
    }

    if (facet === "asn") {
      return (
        row.name ||
        this.rowsFor(facet).find(({ value }) => value === row.value)?.name ||
        `AS${row.value}`
      );
    }

    if (facet === "browser") {
      return i18n(`admin.browser_traffic.browsers.${row.value}`);
    }

    return row.value;
  };

  browserIcon = (browser) => {
    return {
      chrome: "fab-chrome",
      discoursehub: "fab-discourse",
      edge: "fab-edge",
      firefox: "fab-firefox-browser",
      ie: "fab-microsoft",
      opera: "fab-opera",
      safari: "fab-safari",
      unknown: "globe",
    }[browser];
  };

  rowLabel = (facet, row) =>
    i18n("admin.browser_traffic.filter_by", {
      dimension: i18n(DIMENSION_LABELS[facet]),
      value: this.valueLabel(facet, row),
    });

  rowStyle = (facet, row) => {
    const highest = this.rowsFor(facet)[0]?.pageviews || 1;
    return trustHTML(
      `--browser-traffic-row-width: ${(row.pageviews / highest) * 100}%`
    );
  };

  isFacetFiltered = (facet) => Object.hasOwn(this.filters, facet);

  constructor() {
    super(...arguments);
    this.data = this.args.model.result;
    this.errorType = this.args.model.errorType;
    this.filters = { ...this.args.model.filters };
    this.startDate = moment(this.args.model.startDate, "YYYY-MM-DD");
    this.endDate = moment(this.args.model.endDate, "YYYY-MM-DD");
  }

  get filterEntries() {
    return Object.entries(this.filters).map(([facet, value]) => {
      const dimension = i18n(DIMENSION_LABELS[facet]);
      const label = this.valueLabel(facet, { value });

      return {
        facet,
        dimension,
        value: label,
        ariaLabel: i18n("admin.browser_traffic.active_filter", {
          dimension,
          value: label,
        }),
      };
    });
  }

  get hasFilters() {
    return this.filterEntries.length > 0;
  }

  get pageviews() {
    return this.data?.summary.pageviews || 0;
  }

  get loggedInShare() {
    return this.percentage(this.data?.summary.logged_in_pageviews);
  }

  get anonymousShare() {
    return this.percentage(this.data?.summary.anonymous_pageviews);
  }

  get bounceRate() {
    const value = this.data?.summary.bounce_rate;
    return value === null || value === undefined ? "—" : `${value}%`;
  }

  get averageSessionDuration() {
    const value = this.data?.summary.average_session_duration_seconds;
    return value === null || value === undefined
      ? "—"
      : formatMinutesSeconds(value);
  }

  get chartModel() {
    return {
      start_date: this.data?.start_date,
      end_date: this.data?.end_date,
      data: this.data?.pageview_series || [],
    };
  }

  get chartOptions() {
    return { hideYAxisGridLines: true };
  }

  get analysisRange() {
    const startDate = this.data?.start_date;
    const endDate = this.data?.end_date;
    if (!startDate || !endDate) {
      return "";
    }

    return `${moment(startDate, "YYYY-MM-DD").format("ll")} – ${moment(
      endDate,
      "YYYY-MM-DD"
    ).format("ll")}`;
  }

  percentage(value) {
    if (!this.pageviews) {
      return "0%";
    }

    return `${I18n.toNumber(((value || 0) / this.pageviews) * 100, {
      precision: 1,
    })}%`;
  }

  @action
  changeDateRange({ from, to }) {
    if (!from || !to) {
      return;
    }

    this.router.transitionTo("adminBrowserTraffic", {
      queryParams: {
        start_date: from.format("YYYY-MM-DD"),
        end_date: to.format("YYYY-MM-DD"),
      },
    });
  }

  @action
  selectSourceFacet(facet) {
    this.sourceFacet = facet;
  }

  @action
  selectClientFacet(facet) {
    this.clientFacet = facet;
  }

  @action
  addFilter(facet, value) {
    if (this.loading || this.isFacetFiltered(facet)) {
      return;
    }

    this.filters = { ...this.filters, [facet]: value };
    this.updateFilterQueryParams();
    this.load();
  }

  @action
  removeFilter(facet) {
    if (this.loading) {
      return;
    }

    const filters = { ...this.filters };
    delete filters[facet];
    this.filters = filters;
    this.updateFilterQueryParams();
    this.load();
  }

  @action
  clearFilters() {
    if (this.loading) {
      return;
    }

    this.filters = {};
    this.updateFilterQueryParams();
    this.load();
  }

  updateFilterQueryParams() {
    const queryParams = Object.fromEntries(
      Object.values(FILTER_QUERY_PARAMS).map((key) => [key, null])
    );

    for (const [facet, value] of Object.entries(this.filters)) {
      queryParams[FILTER_QUERY_PARAMS[facet]] =
        value === null ? "__null__" : value;
    }

    this.router.replaceWith("adminBrowserTraffic", { queryParams });
  }

  @action
  retry() {
    this.load();
  }

  async load() {
    if (this.loading) {
      return;
    }

    this.loading = true;
    this.errorType = null;

    try {
      this.data = await ajax("/admin/browser-traffic.json", {
        type: "POST",
        contentType: "application/json",
        data: JSON.stringify({
          start_date: this.startDate.format("YYYY-MM-DD"),
          end_date: this.endDate.format("YYYY-MM-DD"),
          snapshot_event_id: this.data?.snapshot_event_id,
          browser_traffic_filters: this.filters,
        }),
      });
      this.a11y.announce(i18n("admin.browser_traffic.loaded"), "polite");
    } catch (error) {
      this.errorType = error.jqXHR?.responseJSON?.error_type || "unknown";
      this.a11y.announce(i18n("admin.browser_traffic.error"), "assertive");
    } finally {
      this.loading = false;
    }
  }

  <template>
    <div class="browser-traffic" ...attributes>
      <div class="browser-traffic__toolbar">
        {{#if this.data}}
          <div class="browser-traffic__analysis">
            <strong>
              {{i18n
                "admin.browser_traffic.analysis.events"
                count=(this.formatCount this.data.analysis.analyzed_events)
              }}
              {{#if this.data.analysis.truncated}}
                <span class="browser-traffic__analysis-limit">
                  ·
                  {{i18n "admin.browser_traffic.analysis.limited"}}
                </span>
                <DTooltip
                  @identifier="browser-traffic-analysis-limit"
                  @icon="circle-info"
                >
                  <:content>
                    {{i18n
                      "admin.browser_traffic.analysis.limited_description"
                      count=(this.formatCount this.data.analysis.event_limit)
                    }}
                  </:content>
                </DTooltip>
              {{/if}}
            </strong>
            <span>{{this.analysisRange}}</span>
          </div>
        {{/if}}
        <DDateTimeInputRange
          @from={{this.startDate}}
          @to={{this.endDate}}
          @onChange={{this.changeDateRange}}
          @showFromTime={{false}}
          @showToTime={{false}}
        />
      </div>

      {{#if this.hasFilters}}
        <div class="browser-traffic__filters">
          {{#each this.filterEntries as |filter|}}
            <DButton
              @action={{fn this.removeFilter filter.facet}}
              @translatedAriaLabel={{filter.ariaLabel}}
              @suffixIcon="xmark"
              @disabled={{this.loading}}
              class="browser-traffic__filter btn-default btn-small"
            >
              <span>{{filter.dimension}}</span>
              <span>{{i18n "admin.browser_traffic.operators.is"}}</span>
              <span
                class="browser-traffic__filter-value"
              >{{filter.value}}</span>
            </DButton>
          {{/each}}
          <DButton
            @action={{this.clearFilters}}
            @label="admin.browser_traffic.clear_all"
            @disabled={{this.loading}}
            class="btn-transparent btn-small"
          />
        </div>
      {{/if}}

      {{#if this.errorType}}
        <div class="browser-traffic__error" role="alert">
          <span>
            {{#if (eq this.errorType "timeout")}}
              {{i18n "admin.browser_traffic.timeout"}}
            {{else}}
              {{i18n "admin.browser_traffic.error"}}
            {{/if}}
          </span>
          <DButton
            @action={{this.retry}}
            @label="admin.browser_traffic.retry"
            class="btn-default btn-small"
          />
        </div>
      {{/if}}

      {{#if this.data}}
        <div
          class={{dConcatClass
            "browser-traffic__results"
            (if this.loading "is-loading")
          }}
        >
          <section class="browser-traffic__metrics">
            <div><strong>{{this.formatCount this.pageviews}}</strong><span
              >{{i18n "admin.browser_traffic.metrics.pageviews"}}</span></div>
            <div><strong>{{this.formatCount
                  this.data.summary.sessions
                }}</strong><span>{{i18n
                  "admin.browser_traffic.metrics.sessions"
                }}</span></div>
            <div><strong>{{this.loggedInShare}}</strong><span>{{i18n
                  "admin.browser_traffic.metrics.logged_in"
                }}</span></div>
            <div><strong>{{this.anonymousShare}}</strong><span>{{i18n
                  "admin.browser_traffic.metrics.anonymous"
                }}</span></div>
            <div><strong>{{this.bounceRate}}</strong><span>{{i18n
                  "admin.browser_traffic.metrics.bounce_rate"
                }}</span></div>
            <div><strong>{{this.averageSessionDuration}}</strong><span>{{i18n
                  "admin.browser_traffic.metrics.average_session_duration"
                }}</span></div>
          </section>

          <section class="browser-traffic__chart">
            <h2>{{i18n "admin.browser_traffic.chart_title"}}</h2>
            <AdminReportStackedChart
              @model={{this.chartModel}}
              @options={{this.chartOptions}}
              class="browser-traffic__chart-canvas"
            />
          </section>

          <div class="browser-traffic__grid">
            <section class="browser-traffic__card">
              <header class="browser-traffic__card-header">
                <nav aria-label={{i18n "admin.browser_traffic.cards.sources"}}>
                  <DButton
                    @action={{fn this.selectSourceFacet "normalized_referrer"}}
                    @label="admin.browser_traffic.tabs.sources"
                    @ariaPressed={{eq this.sourceFacet "normalized_referrer"}}
                    class={{dConcatClass
                      "browser-traffic__tab btn-transparent"
                      (if
                        (eq this.sourceFacet "normalized_referrer") "is-active"
                      )
                    }}
                  />
                  <DButton
                    @action={{fn this.selectSourceFacet "asn"}}
                    @label="admin.browser_traffic.tabs.networks"
                    @ariaPressed={{eq this.sourceFacet "asn"}}
                    class={{dConcatClass
                      "browser-traffic__tab btn-transparent"
                      (if (eq this.sourceFacet "asn") "is-active")
                    }}
                  />
                </nav>
                <span>{{i18n "admin.browser_traffic.pageviews"}}</span>
              </header>
              <div class="browser-traffic__rows">
                {{#each (this.rowsFor this.sourceFacet) as |row|}}
                  <DButton
                    @action={{fn this.addFilter this.sourceFacet row.value}}
                    @translatedAriaLabel={{this.rowLabel this.sourceFacet row}}
                    @disabled={{this.isFacetFiltered this.sourceFacet}}
                    class="browser-traffic__row btn-transparent"
                    style={{this.rowStyle this.sourceFacet row}}
                  >
                    <span class="browser-traffic__bar"></span><span
                      class="browser-traffic__value"
                    >{{this.valueLabel this.sourceFacet row}}</span><strong
                    >{{this.formatCount row.pageviews}}</strong>
                  </DButton>
                {{/each}}
              </div>
            </section>

            <section class="browser-traffic__card">
              <header class="browser-traffic__card-header"><h2>{{i18n
                    "admin.browser_traffic.tabs.pages"
                  }}</h2><span>{{i18n
                    "admin.browser_traffic.pageviews"
                  }}</span></header>
              <div class="browser-traffic__rows">
                {{#each (this.rowsFor "normalized_url") as |row|}}
                  <DButton
                    @action={{fn this.addFilter "normalized_url" row.value}}
                    @translatedAriaLabel={{this.rowLabel "normalized_url" row}}
                    @disabled={{this.isFacetFiltered "normalized_url"}}
                    class="browser-traffic__row btn-transparent"
                    style={{this.rowStyle "normalized_url" row}}
                  >
                    <span class="browser-traffic__bar"></span><span
                      class="browser-traffic__value"
                    >{{this.valueLabel "normalized_url" row}}</span><strong
                    >{{this.formatCount row.pageviews}}</strong>
                  </DButton>
                {{/each}}
              </div>
            </section>

            <section class="browser-traffic__card">
              <header class="browser-traffic__card-header"><h2>{{i18n
                    "admin.browser_traffic.tabs.countries"
                  }}</h2><span>{{i18n
                    "admin.browser_traffic.pageviews"
                  }}</span></header>
              <div class="browser-traffic__rows">
                {{#each (this.rowsFor "country_code") as |row|}}
                  <DButton
                    @action={{fn this.addFilter "country_code" row.value}}
                    @translatedAriaLabel={{this.rowLabel "country_code" row}}
                    @disabled={{this.isFacetFiltered "country_code"}}
                    class="browser-traffic__row btn-transparent"
                    style={{this.rowStyle "country_code" row}}
                  >
                    <span class="browser-traffic__bar"></span><span
                      class="browser-traffic__value"
                    >{{#if row.value}}<span aria-hidden="true">{{countryFlag
                            row.value
                          }}</span>{{/if}}
                      {{this.valueLabel "country_code" row}}</span><strong
                    >{{this.formatCount row.pageviews}}</strong>
                  </DButton>
                {{/each}}
              </div>
            </section>

            <section class="browser-traffic__card">
              <header class="browser-traffic__card-header">
                <nav aria-label={{i18n "admin.browser_traffic.cards.clients"}}>
                  <DButton
                    @action={{fn this.selectClientFacet "browser"}}
                    @label="admin.browser_traffic.tabs.browsers"
                    @ariaPressed={{eq this.clientFacet "browser"}}
                    class={{dConcatClass
                      "browser-traffic__tab btn-transparent"
                      (if (eq this.clientFacet "browser") "is-active")
                    }}
                  />
                  <DButton
                    @action={{fn this.selectClientFacet "ip_address"}}
                    @label="admin.browser_traffic.tabs.ip_addresses"
                    @ariaPressed={{eq this.clientFacet "ip_address"}}
                    class={{dConcatClass
                      "browser-traffic__tab btn-transparent"
                      (if (eq this.clientFacet "ip_address") "is-active")
                    }}
                  />
                </nav>
                <span>{{i18n "admin.browser_traffic.pageviews"}}</span>
              </header>
              <div class="browser-traffic__rows">
                {{#each (this.rowsFor this.clientFacet) as |row|}}
                  <DButton
                    @action={{fn this.addFilter this.clientFacet row.value}}
                    @translatedAriaLabel={{this.rowLabel this.clientFacet row}}
                    @disabled={{this.isFacetFiltered this.clientFacet}}
                    class="browser-traffic__row btn-transparent"
                    style={{this.rowStyle this.clientFacet row}}
                  >
                    <span class="browser-traffic__bar"></span><span
                      class="browser-traffic__value"
                    >{{#if (eq this.clientFacet "browser")}}
                        {{dIcon (this.browserIcon row.value)}}
                      {{/if}}
                      {{this.valueLabel this.clientFacet row}}</span><strong
                    >{{this.formatCount row.pageviews}}</strong>
                  </DButton>
                {{/each}}
              </div>
            </section>

          </div>
        </div>
      {{/if}}
    </div>
  </template>
}
