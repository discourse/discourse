import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import Chart from "discourse/admin/components/chart";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { number } from "discourse/lib/formatter";
import ComboBox from "discourse/select-kit/components/combo-box";
import { eq, gt } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DDateTimeInputRange from "discourse/ui-kit/d-date-time-input-range";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import DStatTiles from "discourse/ui-kit/d-stat-tiles";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { normalizeAiUsageTimeSeriesData } from "discourse/plugins/discourse-ai/discourse/lib/ai-usage-time-series";
import AiCreditBar from "./ai-credit-bar";

const DATE_FORMAT = "YYYY-MM-DD";
const DEFAULT_PERIOD = "month";
const CUSTOM_PERIOD = "custom";
const PRESET_PERIODS = ["day", "week", DEFAULT_PERIOD];

export default class AiUsage extends Component {
  @service currentUser;
  @service router;

  @tracked startDate = moment().subtract(30, "days").toDate();
  @tracked endDate = new Date();
  @tracked data = this.args.model;
  @tracked selectedFeature;
  @tracked selectedModel;
  @tracked selectedPeriod = DEFAULT_PERIOD;
  @tracked isCustomDateActive = false;
  @tracked loadingData = true;
  @tracked filterOptionsData;

  constructor() {
    super(...arguments);
    this.initializeFilters(this.args.queryParams);
    this.fetchData();
    if (this.selectedFeature || this.selectedModel) {
      this.fetchFilterOptions();
    }
  }

  initializeFilters(queryParams = {}) {
    const hasCustomDateParams = queryParams.start_date || queryParams.end_date;

    if (
      queryParams.period === CUSTOM_PERIOD ||
      (!this.isPresetPeriod(queryParams.period) && hasCustomDateParams)
    ) {
      this.selectedPeriod = CUSTOM_PERIOD;
      this.isCustomDateActive = true;
      this.startDate =
        this.parseDateParam(queryParams.start_date) || this.startDate;
      this.endDate = this.parseDateParam(queryParams.end_date) || this.endDate;
    } else if (this.isPresetPeriod(queryParams.period)) {
      this.selectedPeriod = queryParams.period;
      this.isCustomDateActive = false;
      this.setPeriodDates(queryParams.period);
    } else {
      this.selectedPeriod = DEFAULT_PERIOD;
      this.isCustomDateActive = false;
      this.setPeriodDates(DEFAULT_PERIOD);
    }

    this.selectedFeature = queryParams.feature || undefined;
    this.selectedModel = queryParams.model
      ? String(queryParams.model)
      : undefined;
  }

  isPresetPeriod(period) {
    return PRESET_PERIODS.includes(period);
  }

  parseDateParam(date) {
    if (!date) {
      return null;
    }

    const parsedDate = moment(date, DATE_FORMAT, true);
    if (parsedDate.isValid()) {
      return parsedDate.toDate();
    }

    const parsedDateTime = moment(date);
    return parsedDateTime.isValid() ? parsedDateTime.toDate() : null;
  }

  formatDateParam(date) {
    return date ? moment(date).format(DATE_FORMAT) : null;
  }

  formatRequestDate(date) {
    return moment(date).format();
  }

  get requestStartDate() {
    return this.selectedPeriod === CUSTOM_PERIOD
      ? this.formatDateParam(this.startDate)
      : this.formatRequestDate(this.startDate);
  }

  get requestEndDate() {
    return this.selectedPeriod === CUSTOM_PERIOD
      ? this.formatDateParam(this.endDate)
      : this.formatRequestDate(this.endDate);
  }

  get baseReportParams() {
    return {
      start_date: this.requestStartDate,
      end_date: this.requestEndDate,
      timezone: this.currentUser?.user_option?.timezone || moment.tz.guess(),
    };
  }

  get reportParams() {
    return {
      ...this.baseReportParams,
      feature: this.selectedFeature || undefined,
      model: this.selectedModel || undefined,
    };
  }

  @action
  async fetchData() {
    const requestId = (this._dataRequestId = (this._dataRequestId || 0) + 1);
    const response = await ajax(
      "/admin/plugins/discourse-ai/ai-usage-report.json",
      { data: this.reportParams }
    );

    if (
      requestId !== this._dataRequestId ||
      this.isDestroying ||
      this.isDestroyed
    ) {
      return;
    }

    this.data = response;
    if (!this.selectedFeature && !this.selectedModel) {
      this.filterOptionsData = response;
    }
    this.loadingData = false;
  }

  async fetchFilterOptions() {
    const requestId = (this._filterOptionsRequestId =
      (this._filterOptionsRequestId || 0) + 1);
    const response = await ajax(
      "/admin/plugins/discourse-ai/ai-usage-report.json",
      { data: this.baseReportParams }
    );

    if (
      requestId !== this._filterOptionsRequestId ||
      this.isDestroying ||
      this.isDestroyed
    ) {
      return;
    }

    this.filterOptionsData = response;
  }

  get filterQueryParams() {
    const queryParams = {
      period:
        this.selectedPeriod === DEFAULT_PERIOD ? null : this.selectedPeriod,
      start_date: null,
      end_date: null,
      feature: this.selectedFeature || null,
      model: this.selectedModel || null,
    };

    if (this.selectedPeriod === CUSTOM_PERIOD) {
      queryParams.period = CUSTOM_PERIOD;
      queryParams.start_date = this.formatDateParam(this.startDate);
      queryParams.end_date = this.formatDateParam(this.endDate);
    }

    return queryParams;
  }

  updateQueryParams() {
    this.router.transitionTo(this.router.currentRouteName, {
      queryParams: this.filterQueryParams,
    });
  }

  @action
  async onFilterChange() {
    this.updateQueryParams();
    await this.fetchData();
  }

  async onDateRangeFilterChange() {
    this.updateQueryParams();

    if (this.selectedFeature || this.selectedModel) {
      await Promise.all([this.fetchData(), this.fetchFilterOptions()]);
    } else {
      await this.fetchData();
    }
  }

  @action
  onFeatureChanged(value) {
    this.selectedFeature = value || undefined;
    this.onFilterChange();
  }

  @action
  onModelChanged(value) {
    this.selectedModel = value ? String(value) : undefined;
    this.onFilterChange();
  }

  @action
  addCurrencyChar(element) {
    element.querySelectorAll(".d-stat-tile__label").forEach((label) => {
      if (
        label.innerText.trim() === i18n("discourse_ai.usage.total_spending")
      ) {
        const valueElement = label
          .closest(".d-stat-tile")
          ?.querySelector(".d-stat-tile__value");
        if (valueElement) {
          valueElement.innerText = `$${valueElement.innerText}`;
        }
      }
    });
  }

  @bind
  takeUsers(start, end) {
    return this.data.users.slice(start, end);
  }

  get userSplitPoint() {
    if (!this.data?.users) {
      return 0;
    }
    return Math.ceil(this.data.users.length / 2);
  }

  normalizeTimeSeriesData(data) {
    return normalizeAiUsageTimeSeriesData(
      data,
      this.data.period,
      this.data.summary?.date_range
    );
  }

  get metrics() {
    return [
      {
        label: i18n("discourse_ai.usage.total_requests"),
        value: this.data.summary.total_requests,
        tooltip: i18n("discourse_ai.usage.stat_tooltips.total_requests"),
      },
      {
        label: i18n("discourse_ai.usage.total_tokens"),
        value: this.data.summary.total_tokens,
        tooltip: i18n("discourse_ai.usage.stat_tooltips.total_tokens"),
      },
      {
        label: i18n("discourse_ai.usage.request_tokens"),
        value: this.data.summary.total_request_tokens,
        tooltip: i18n("discourse_ai.usage.stat_tooltips.request_tokens"),
      },
      {
        label: i18n("discourse_ai.usage.response_tokens"),
        value: this.data.summary.total_response_tokens,
        tooltip: i18n("discourse_ai.usage.stat_tooltips.response_tokens"),
      },
      {
        label: i18n("discourse_ai.usage.cache_read_tokens"),
        value: this.data.summary.total_cache_read_tokens,
        tooltip: i18n("discourse_ai.usage.stat_tooltips.cache_read_tokens"),
      },
      {
        label: i18n("discourse_ai.usage.cache_write_tokens"),
        value: this.data.summary.total_cache_write_tokens,
        tooltip: i18n("discourse_ai.usage.stat_tooltips.cache_write_tokens"),
      },
      {
        label: i18n("discourse_ai.usage.total_spending"),
        value: this.data.summary.total_spending,
        tooltip: i18n("discourse_ai.usage.stat_tooltips.total_spending"),
      },
    ];
  }

  get chartConfig() {
    if (!this.data?.data) {
      return;
    }

    const normalizedData = this.normalizeTimeSeriesData(this.data.data);

    const chartEl = document.querySelector(".ai-usage__chart");
    const computedStyle = getComputedStyle(chartEl);

    const colors = {
      response: computedStyle.getPropertyValue("--chart-response-color").trim(),
      request: computedStyle.getPropertyValue("--chart-request-color").trim(),
      cacheRead: computedStyle
        .getPropertyValue("--chart-cache-read-color")
        .trim(),
      cacheWrite: computedStyle
        .getPropertyValue("--chart-cache-write-color")
        .trim(),
    };

    return {
      type: "bar",
      data: {
        labels: normalizedData.map((row) => {
          const date = moment(row.period);
          if (this.data.period === "hour") {
            return date.format("HH:00");
          } else if (this.data.period === "day") {
            return date.format("DD-MMM");
          } else {
            return date.format("MMM-YY");
          }
        }),
        datasets: [
          {
            label: i18n("discourse_ai.usage.response_tokens"),
            data: normalizedData.map((row) => row.total_response_tokens),
            backgroundColor: colors.response,
          },
          {
            label: i18n("discourse_ai.usage.request_tokens"),
            data: normalizedData.map((row) => row.total_request_tokens),
            backgroundColor: colors.request,
          },
          {
            label: i18n("discourse_ai.usage.cache_read_tokens"),
            data: normalizedData.map((row) => row.total_cache_read_tokens),
            backgroundColor: colors.cacheRead,
          },
          {
            label: i18n("discourse_ai.usage.cache_write_tokens"),
            data: normalizedData.map((row) => row.total_cache_write_tokens),
            backgroundColor: colors.cacheWrite,
          },
        ],
      },
      options: {
        responsive: true,
        scales: {
          x: {
            stacked: true,
          },
          y: {
            stacked: true,
            beginAtZero: true,
          },
        },
      },
    };
  }

  get modelsWithCredits() {
    return (this.data?.models || []).filter((m) => m.credit_allocation);
  }

  get modelsWithoutCredits() {
    return (this.data?.models || []).filter((m) => !m.credit_allocation);
  }

  get featuresTotals() {
    const features = this.data?.features || [];
    let totalSpending = 0;

    features.forEach((f) => {
      const costType = this.getFeatureCostType(f.feature_name);
      if (costType === "included") {
        // Don't add to total - included in plan
      } else if (costType === "mixed") {
        totalSpending += this.getCostOnlySpending(f.feature_name);
      } else {
        totalSpending += this.spendingValue(f);
      }
    });

    return {
      usage_count: features.reduce((sum, f) => sum + (f.usage_count || 0), 0),
      total_tokens: features.reduce((sum, f) => sum + (f.total_tokens || 0), 0),
      total_spending: totalSpending,
    };
  }

  get modelsWithoutCreditsTotals() {
    const models = this.modelsWithoutCredits || [];
    return {
      usage_count: models.reduce((sum, m) => sum + (m.usage_count || 0), 0),
      total_tokens: models.reduce((sum, m) => sum + (m.total_tokens || 0), 0),
      total_spending: models.reduce(
        (sum, model) => sum + this.spendingValue(model),
        0
      ),
    };
  }

  get usersTotals() {
    const users = this.data?.users || [];
    return {
      usage_count: users.reduce((sum, u) => sum + (u.usage_count || 0), 0),
      total_tokens: users.reduce((sum, u) => sum + (u.total_tokens || 0), 0),
      total_spending: users.reduce(
        (sum, user) => sum + this.spendingValue(user),
        0
      ),
    };
  }

  spendingValue(row) {
    return (
      row.total_spending ??
      (row.input_spending || 0) +
        (row.cache_read_spending || 0) +
        (row.cache_write_spending || 0) +
        (row.output_spending || 0)
    );
  }

  @bind
  formatSpending(value) {
    return `$${(value || 0).toFixed(2)}`;
  }

  @bind
  getFeatureCostType(featureName) {
    const models = this.data?.feature_models?.[featureName] || [];
    if (models.length === 0) {
      return "cost";
    }

    const hasIncluded = models.some((m) => m.credit_allocation);
    const hasCost = models.some((m) => !m.credit_allocation);

    if (hasIncluded && !hasCost) {
      return "included";
    }
    if (!hasIncluded && hasCost) {
      return "cost";
    }
    return "mixed";
  }

  @bind
  getIncludedModelsForFeature(featureName) {
    return (this.data?.feature_models?.[featureName] || []).filter(
      (m) => m.credit_allocation
    );
  }

  @bind
  getCostModelsForFeature(featureName) {
    return (this.data?.feature_models?.[featureName] || []).filter(
      (m) => !m.credit_allocation
    );
  }

  @bind
  getCostOnlySpending(featureName) {
    const costModels = this.getCostModelsForFeature(featureName);
    return costModels.reduce(
      (sum, model) => sum + this.spendingValue(model),
      0
    );
  }

  @bind
  hasIncludedModelsForFeature(featureName) {
    return this.getIncludedModelsForFeature(featureName).length > 0;
  }

  @bind
  hasCostModelsForFeature(featureName) {
    return this.getCostModelsForFeature(featureName).length > 0;
  }

  get availableFeatures() {
    const features =
      this.filterOptionsData?.features || this.data?.features || [];

    return features.map((feature) => ({
      id: feature.feature_name,
      name: feature.feature_name,
    }));
  }

  get availableModels() {
    const models = this.filterOptionsData?.models || this.data?.models || [];

    return models.map((model) => ({
      id: String(model.id),
      name: model.llm,
    }));
  }

  get periodOptions() {
    return [
      { id: "day", name: i18n("discourse_ai.usage.periods.last_day") },
      { id: "week", name: i18n("discourse_ai.usage.periods.last_week") },
      { id: "month", name: i18n("discourse_ai.usage.periods.last_month") },
    ];
  }

  @action
  setPeriodDates(period) {
    const now = moment();

    switch (period) {
      case "day":
        this.startDate = now.clone().subtract(1, "day").toDate();
        this.endDate = now.toDate();
        break;
      case "week":
        this.startDate = now.clone().subtract(7, "days").toDate();
        this.endDate = now.toDate();
        break;
      case DEFAULT_PERIOD:
        this.startDate = now.clone().subtract(30, "days").toDate();
        this.endDate = now.toDate();
        break;
    }
  }

  @action
  onPeriodSelect(period) {
    this.selectedPeriod = period;
    this.isCustomDateActive = false;
    this.setPeriodDates(period);
    this.onDateRangeFilterChange();
  }

  @action
  onCustomDateClick() {
    this.isCustomDateActive = !this.isCustomDateActive;

    if (this.isCustomDateActive) {
      this.selectedPeriod = CUSTOM_PERIOD;
    } else {
      this.selectedPeriod = DEFAULT_PERIOD;
      this.setPeriodDates(DEFAULT_PERIOD);
      this.onDateRangeFilterChange();
    }
  }

  @action
  onChangeDateRange({ from, to }) {
    this._startDate = from;
    this._endDate = to;
  }

  @action
  onRefreshDateRange() {
    this.isCustomDateActive = true;
    this.selectedPeriod = CUSTOM_PERIOD;
    this.startDate = this._startDate || this.startDate;
    this.endDate = this._endDate || this.endDate;
    this.onDateRangeFilterChange();
    this._startDate = null;
    this._endDate = null;
  }

  get fromDate() {
    return this._startDate || this.startDate;
  }

  get toDate() {
    return this._endDate || this.endDate;
  }

  @bind
  totalSpending(
    inputSpending,
    cacheReadSpending,
    cacheWriteSpending,
    outputSpending,
    estimatedSpending
  ) {
    const total =
      estimatedSpending ??
      (inputSpending || 0) +
        (cacheReadSpending || 0) +
        (cacheWriteSpending || 0) +
        (outputSpending || 0);
    return `$${total.toFixed(2)}`;
  }

  <template>
    <div class="ai-usage admin-detail">
      <DPageSubheader
        @titleLabel={{i18n "discourse_ai.usage.short_title"}}
        @learnMoreUrl="https://meta.discourse.org/t/-/348677"
        @descriptionLabel={{i18n "discourse_ai.usage.subheader_description"}}
      />
      <div class="ai-usage__filters">
        <div class="ai-usage__filters-dates">
          <div class="ai-usage__period-buttons">
            {{#each this.periodOptions as |option|}}
              <DButton
                class={{if
                  (eq this.selectedPeriod option.id)
                  "btn-primary"
                  "btn-default"
                }}
                @action={{fn this.onPeriodSelect option.id}}
                @translatedLabel={{option.name}}
              />
            {{/each}}
            <DButton
              class={{if this.isCustomDateActive "btn-primary" "btn-default"}}
              @action={{this.onCustomDateClick}}
              @label="discourse_ai.usage.periods.custom"
            />
          </div>

          {{#if this.isCustomDateActive}}
            <div class="ai-usage__custom-date-pickers">

              <DDateTimeInputRange
                @from={{this.fromDate}}
                @to={{this.toDate}}
                @onChange={{this.onChangeDateRange}}
                @showFromTime={{false}}
                @showToTime={{false}}
              />

              <DButton @action={{this.onRefreshDateRange}} @label="refresh" />
            </div>
          {{/if}}
        </div>

        <div class="ai-usage__filters-row">
          <ComboBox
            @value={{this.selectedFeature}}
            @content={{this.availableFeatures}}
            @onChange={{this.onFeatureChanged}}
            @options={{hash none="discourse_ai.usage.all_features"}}
            class="ai-usage__feature-selector"
          />

          <ComboBox
            @value={{this.selectedModel}}
            @content={{this.availableModels}}
            @onChange={{this.onModelChanged}}
            @options={{hash none="discourse_ai.usage.all_models"}}
            class="ai-usage__model-selector"
          />
        </div>

        <DConditionalLoadingSpinner @condition={{this.loadingData}}>
          <AdminConfigAreaCard
            @heading="discourse_ai.usage.summary"
            class="ai-usage__summary"
          >
            <:content>
              <DStatTiles
                {{didInsert this.addCurrencyChar this.metrics}}
                {{didUpdate this.addCurrencyChar this.metrics}}
                as |tiles|
              >

                {{#each this.metrics as |metric|}}
                  <tiles.Tile
                    class="bar"
                    @label={{metric.label}}
                    @href={{metric.href}}
                    @value={{metric.value}}
                    @tooltip={{metric.tooltip}}
                  />
                {{/each}}
              </DStatTiles>
            </:content>
          </AdminConfigAreaCard>

          <AdminConfigAreaCard
            class="ai-usage__charts"
            @heading="discourse_ai.usage.tokens_over_time"
          >
            <:content>
              <div class="ai-usage__chart-container">
                <Chart
                  @chartConfig={{this.chartConfig}}
                  class="ai-usage__chart"
                />
              </div>
            </:content>
          </AdminConfigAreaCard>

          <div class="ai-usage__breakdowns">
            <AdminConfigAreaCard
              class="ai-usage__features"
              @heading="discourse_ai.usage.features_breakdown"
            >
              <:content>
                {{#unless this.data.features.length}}
                  <AdminConfigAreaEmptyList
                    @emptyLabel="discourse_ai.usage.no_features"
                  />
                {{/unless}}

                {{#if this.data.features.length}}
                  <table class="ai-usage__features-table">
                    <thead>
                      <tr>
                        <th>{{i18n "discourse_ai.usage.feature"}}</th>
                        <th>{{i18n "discourse_ai.usage.usage_count"}}</th>
                        <th>{{i18n "discourse_ai.usage.total_tokens"}}</th>
                        <th>{{i18n "discourse_ai.usage.total_spending"}}</th>
                      </tr>
                    </thead>
                    <tbody>
                      {{#each this.data.features as |feature|}}
                        <tr class="ai-usage__features-row">
                          <td
                            class="ai-usage__features-cell"
                          >{{feature.feature_name}}</td>
                          <td
                            class="ai-usage__features-cell"
                            title={{feature.usage_count}}
                          >{{number feature.usage_count}}</td>
                          <td
                            class="ai-usage__features-cell"
                            title={{feature.total_tokens}}
                          >{{number feature.total_tokens}}</td>
                          <td class="ai-usage__features-cell">
                            {{#if
                              (eq
                                (this.getFeatureCostType feature.feature_name)
                                "included"
                              )
                            }}
                              <span class="ai-usage__included-label">
                                {{i18n "discourse_ai.usage.included_in_plan"}}
                              </span>
                            {{else if
                              (eq
                                (this.getFeatureCostType feature.feature_name)
                                "cost"
                              )
                            }}
                              {{this.totalSpending
                                feature.input_spending
                                feature.cache_read_spending
                                feature.cache_write_spending
                                feature.output_spending
                                feature.total_spending
                              }}
                            {{else}}
                              <span class="ai-usage__mixed-cost">
                                {{this.formatSpending
                                  (this.getCostOnlySpending
                                    feature.feature_name
                                  )
                                }}
                                <DTooltip
                                  @identifier="ai-usage-feature-breakdown"
                                  @placement="top"
                                  @interactive={{true}}
                                  @maxWidth={{600}}
                                >
                                  <:trigger>
                                    {{dIcon
                                      "circle-question"
                                      class="ai-usage__info-icon"
                                    }}
                                  </:trigger>
                                  <:content>
                                    <div class="ai-usage__cost-breakdown">
                                      {{#if
                                        (this.hasIncludedModelsForFeature
                                          feature.feature_name
                                        )
                                      }}
                                        <div
                                          class="ai-usage__breakdown-section"
                                        >
                                          <h4>{{i18n
                                              "discourse_ai.usage.included_models"
                                            }}</h4>
                                          <table
                                            class="ai-usage__breakdown-table"
                                          >
                                            <thead>
                                              <tr>
                                                <th>{{i18n
                                                    "discourse_ai.usage.model"
                                                  }}</th>
                                                <th>{{i18n
                                                    "discourse_ai.usage.usage_count"
                                                  }}</th>
                                                <th>{{i18n
                                                    "discourse_ai.usage.total_tokens"
                                                  }}</th>
                                                <th>{{i18n
                                                    "discourse_ai.usage.cost"
                                                  }}</th>
                                              </tr>
                                            </thead>
                                            <tbody>
                                              {{#each
                                                (this.getIncludedModelsForFeature
                                                  feature.feature_name
                                                )
                                                as |model|
                                              }}
                                                <tr>
                                                  <td>{{model.llm}}</td>
                                                  <td>{{number
                                                      model.usage_count
                                                    }}</td>
                                                  <td>{{number
                                                      model.total_tokens
                                                    }}</td>
                                                  <td>{{i18n
                                                      "discourse_ai.usage.included_in_plan"
                                                    }}</td>
                                                </tr>
                                              {{/each}}
                                            </tbody>
                                          </table>
                                        </div>
                                      {{/if}}
                                      {{#if
                                        (this.hasCostModelsForFeature
                                          feature.feature_name
                                        )
                                      }}
                                        <div
                                          class="ai-usage__breakdown-section"
                                        >
                                          <h4>{{i18n
                                              "discourse_ai.usage.billed_models"
                                            }}</h4>
                                          <table
                                            class="ai-usage__breakdown-table"
                                          >
                                            <thead>
                                              <tr>
                                                <th>{{i18n
                                                    "discourse_ai.usage.model"
                                                  }}</th>
                                                <th>{{i18n
                                                    "discourse_ai.usage.usage_count"
                                                  }}</th>
                                                <th>{{i18n
                                                    "discourse_ai.usage.total_tokens"
                                                  }}</th>
                                                <th>{{i18n
                                                    "discourse_ai.usage.cost"
                                                  }}</th>
                                              </tr>
                                            </thead>
                                            <tbody>
                                              {{#each
                                                (this.getCostModelsForFeature
                                                  feature.feature_name
                                                )
                                                as |model|
                                              }}
                                                <tr>
                                                  <td>{{model.llm}}</td>
                                                  <td>{{number
                                                      model.usage_count
                                                    }}</td>
                                                  <td>{{number
                                                      model.total_tokens
                                                    }}</td>
                                                  <td>{{this.totalSpending
                                                      model.input_spending
                                                      model.cache_read_spending
                                                      model.cache_write_spending
                                                      model.output_spending
                                                      model.total_spending
                                                    }}</td>
                                                </tr>
                                              {{/each}}
                                            </tbody>
                                          </table>
                                        </div>
                                      {{/if}}
                                    </div>
                                  </:content>
                                </DTooltip>
                              </span>
                            {{/if}}
                          </td>
                        </tr>
                      {{/each}}
                      <tr class="ai-usage__total-row">
                        <td>{{i18n "discourse_ai.usage.total"}}</td>
                        <td title={{this.featuresTotals.usage_count}}>{{number
                            this.featuresTotals.usage_count
                          }}</td>
                        <td title={{this.featuresTotals.total_tokens}}>{{number
                            this.featuresTotals.total_tokens
                          }}</td>
                        <td>{{this.formatSpending
                            this.featuresTotals.total_spending
                          }}</td>
                      </tr>
                    </tbody>
                  </table>
                {{/if}}
              </:content>
            </AdminConfigAreaCard>

            <AdminConfigAreaCard
              class="ai-usage__models"
              @heading="discourse_ai.usage.models_breakdown"
            >
              <:content>
                {{#unless this.data.models.length}}
                  <AdminConfigAreaEmptyList
                    @emptyLabel="discourse_ai.usage.no_models"
                  />
                {{/unless}}

                {{#if this.modelsWithCredits.length}}
                  <table class="ai-usage__models-table">
                    <thead>
                      <tr>
                        <th>{{i18n "discourse_ai.usage.model"}}</th>
                        <th>{{i18n "discourse_ai.usage.usage_count"}}</th>
                        <th>{{i18n "discourse_ai.usage.total_tokens"}}</th>
                        <th>{{i18n "discourse_ai.usage.credits_remaining"}}</th>
                      </tr>
                    </thead>
                    <tbody>
                      {{#each this.modelsWithCredits as |model|}}
                        <tr class="ai-usage__models-row">
                          <td class="ai-usage__models-cell">{{model.llm}}</td>
                          <td
                            class="ai-usage__models-cell"
                            title={{model.usage_count}}
                          >{{number model.usage_count}}</td>
                          <td
                            class="ai-usage__models-cell"
                            title={{model.total_tokens}}
                          >{{number model.total_tokens}}</td>
                          <td class="ai-usage__models-credit-bar">
                            <AiCreditBar
                              @allocation={{model.credit_allocation}}
                              @compact={{true}}
                            />
                          </td>
                        </tr>
                      {{/each}}
                    </tbody>
                  </table>
                {{/if}}

                {{#if this.modelsWithoutCredits.length}}
                  <table class="ai-usage__models-table">
                    <thead>
                      <tr>
                        <th>{{i18n "discourse_ai.usage.model"}}</th>
                        <th>{{i18n "discourse_ai.usage.usage_count"}}</th>
                        <th>{{i18n "discourse_ai.usage.total_tokens"}}</th>
                        <th>{{i18n "discourse_ai.usage.total_spending"}}</th>
                      </tr>
                    </thead>
                    <tbody>
                      {{#each this.modelsWithoutCredits as |model|}}
                        <tr class="ai-usage__models-row">
                          <td class="ai-usage__models-cell">{{model.llm}}</td>
                          <td
                            class="ai-usage__models-cell"
                            title={{model.usage_count}}
                          >{{number model.usage_count}}</td>
                          <td
                            class="ai-usage__models-cell"
                            title={{model.total_tokens}}
                          >{{number model.total_tokens}}</td>
                          <td>
                            {{this.totalSpending
                              model.input_spending
                              model.cache_read_spending
                              model.cache_write_spending
                              model.output_spending
                              model.total_spending
                            }}
                          </td>
                        </tr>
                      {{/each}}
                      <tr class="ai-usage__total-row">
                        <td>{{i18n "discourse_ai.usage.total"}}</td>
                        <td
                          title={{this.modelsWithoutCreditsTotals.usage_count}}
                        >{{number
                            this.modelsWithoutCreditsTotals.usage_count
                          }}</td>
                        <td
                          title={{this.modelsWithoutCreditsTotals.total_tokens}}
                        >{{number
                            this.modelsWithoutCreditsTotals.total_tokens
                          }}</td>
                        <td>{{this.formatSpending
                            this.modelsWithoutCreditsTotals.total_spending
                          }}</td>
                      </tr>
                    </tbody>
                  </table>
                {{/if}}
              </:content>
            </AdminConfigAreaCard>

            <AdminConfigAreaCard
              class="ai-usage__users"
              @heading="discourse_ai.usage.users_breakdown"
            >
              <:content>
                {{#unless this.data.users.length}}
                  <AdminConfigAreaEmptyList
                    @emptyLabel="discourse_ai.usage.no_users"
                  />
                {{/unless}}

                {{#if this.data.users.length}}
                  <div
                    class={{dConcatClass
                      "ai-usage__users-table-wrapper"
                      (if (gt this.data.users.length 24) "-multi-column")
                    }}
                  >
                    <table class="ai-usage__users-table">
                      <thead>
                        <tr>
                          <th class="ai-usage__users-username">{{i18n
                              "discourse_ai.usage.username"
                            }}</th>
                          <th>{{i18n "discourse_ai.usage.usage_count"}}</th>
                          <th>{{i18n "discourse_ai.usage.total_tokens"}}</th>
                          <th>{{i18n "discourse_ai.usage.total_spending"}}</th>
                        </tr>
                      </thead>
                      <tbody>
                        {{#each
                          (this.takeUsers 0 this.userSplitPoint)
                          as |user|
                        }}
                          <tr class="ai-usage__users-row">
                            <td class="ai-usage__users-cell">
                              <div class="user-info">
                                <LinkTo
                                  @route="user"
                                  @model={{user.username}}
                                  class="username"
                                >
                                  {{dAvatar user imageSize="tiny"}}
                                  {{user.username}}
                                </LinkTo>
                              </div></td>
                            <td
                              class="ai-usage__users-cell"
                              title={{user.usage_count}}
                            >{{number user.usage_count}}</td>
                            <td
                              class="ai-usage__users-cell"
                              title={{user.total_tokens}}
                            >{{number user.total_tokens}}</td>
                            <td>
                              {{this.totalSpending
                                user.input_spending
                                user.cache_read_spending
                                user.cache_write_spending
                                user.output_spending
                                user.total_spending
                              }}
                            </td>
                          </tr>
                        {{/each}}
                        {{#unless (gt this.data.users.length 24)}}
                          <tr class="ai-usage__total-row">
                            <td>{{i18n "discourse_ai.usage.total"}}</td>
                            <td title={{this.usersTotals.usage_count}}>{{number
                                this.usersTotals.usage_count
                              }}</td>
                            <td title={{this.usersTotals.total_tokens}}>{{number
                                this.usersTotals.total_tokens
                              }}</td>
                            <td>{{this.formatSpending
                                this.usersTotals.total_spending
                              }}</td>
                          </tr>
                        {{/unless}}
                      </tbody>
                    </table>

                    {{#if (gt this.data.users.length 24)}}
                      <table class="ai-usage__users-table">
                        <thead>
                          <tr>
                            <th class="ai-usage__users-username">{{i18n
                                "discourse_ai.usage.username"
                              }}</th>
                            <th>{{i18n "discourse_ai.usage.usage_count"}}</th>
                            <th>{{i18n "discourse_ai.usage.total_tokens"}}</th>
                            <th>{{i18n
                                "discourse_ai.usage.total_spending"
                              }}</th>
                          </tr>
                        </thead>
                        <tbody>
                          {{#each
                            (this.takeUsers this.userSplitPoint 50)
                            as |user|
                          }}
                            <tr class="ai-usage__users-row">
                              <td class="ai-usage__users-cell">
                                <div class="user-info">
                                  <LinkTo
                                    @route="user"
                                    @model={{user.username}}
                                    class="username"
                                  >
                                    {{dAvatar user imageSize="tiny"}}
                                    {{user.username}}
                                  </LinkTo>
                                </div></td>
                              <td
                                class="ai-usage__users-cell"
                                title={{user.usage_count}}
                              >{{number user.usage_count}}</td>
                              <td
                                class="ai-usage__users-cell"
                                title={{user.total_tokens}}
                              >{{number user.total_tokens}}</td>
                              <td>
                                {{this.totalSpending
                                  user.input_spending
                                  user.cache_read_spending
                                  user.cache_write_spending
                                  user.output_spending
                                  user.total_spending
                                }}
                              </td>
                            </tr>
                          {{/each}}
                          <tr class="ai-usage__total-row">
                            <td>{{i18n "discourse_ai.usage.total"}}</td>
                            <td title={{this.usersTotals.usage_count}}>{{number
                                this.usersTotals.usage_count
                              }}</td>
                            <td title={{this.usersTotals.total_tokens}}>{{number
                                this.usersTotals.total_tokens
                              }}</td>
                            <td>{{this.formatSpending
                                this.usersTotals.total_spending
                              }}</td>
                          </tr>
                        </tbody>
                      </table>
                    {{/if}}
                  </div>
                {{/if}}
              </:content>
            </AdminConfigAreaCard>
          </div>
        </DConditionalLoadingSpinner>
      </div>
    </div>
  </template>
}
