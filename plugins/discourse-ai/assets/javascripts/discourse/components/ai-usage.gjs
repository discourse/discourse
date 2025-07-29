import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { eq, gt, lt } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import DStatTiles from "discourse/components/d-stat-tiles";
import DateTimeInputRange from "discourse/components/date-time-input-range";
import avatar from "discourse/helpers/avatar";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { number } from "discourse/lib/formatter";
import { i18n } from "discourse-i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import AdminConfigAreaEmptyList from "admin/components/admin-config-area-empty-list";
import Chart from "admin/components/chart";
import ComboBox from "select-kit/components/combo-box";

export default class AiUsage extends Component {
  @service store;
  @service currentUser;

  @tracked startDate = moment().subtract(30, "days").toDate();
  @tracked endDate = new Date();
  @tracked data = this.args.model;
  @tracked selectedFeature;
  @tracked selectedModel;
  @tracked selectedPeriod = "month";
  @tracked isCustomDateActive = false;
  @tracked loadingData = true;

  constructor() {
    super(...arguments);
    this.fetchData();
  }

  @action
  async fetchData() {
    const response = await ajax(
      "/admin/plugins/discourse-ai/ai-usage-report.json",
      {
        data: {
          start_date: moment(this.startDate).format("YYYY-MM-DD"),
          end_date: moment(this.endDate).format("YYYY-MM-DD"),
          timezone:
            this.currentUser?.user_option?.timezone || moment.tz.guess(),
          feature: this.selectedFeature,
          model: this.selectedModel,
        },
      }
    );
    this.data = response;
    this.loadingData = false;
    this._cachedFeatures = null;
    this._cachedModels = null;
  }

  @action
  async onFilterChange() {
    await this.fetchData();
  }

  @action
  onFeatureChanged(value) {
    this.selectedFeature = value;
    this.onFilterChange();
  }

  @action
  onModelChanged(value) {
    this.selectedModel = value;
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

  normalizeTimeSeriesData(data) {
    if (!data?.length) {
      return [];
    }

    const startDate = moment(this.startDate);
    const endDate = moment(this.endDate);
    const normalized = [];
    let interval;
    let format;

    if (this.data.period === "hour") {
      interval = "hour";
      format = "YYYY-MM-DD HH:00:00";
    } else if (this.data.period === "day") {
      interval = "day";
      format = "YYYY-MM-DD";
    } else {
      interval = "month";
      format = "YYYY-MM";
    }
    const dataMap = new Map(
      data.map((d) => [moment(d.period).format(format), d])
    );

    for (
      let currentMoment = moment(startDate);
      currentMoment.isSameOrBefore(endDate);
      currentMoment.add(1, interval)
    ) {
      const dateKey = currentMoment.format(format);
      const existingData = dataMap.get(dateKey);

      normalized.push(
        existingData || {
          period: currentMoment.format(),
          total_tokens: 0,
          total_cached_tokens: 0,
          total_request_tokens: 0,
          total_response_tokens: 0,
        }
      );
    }

    return normalized;
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
        label: i18n("discourse_ai.usage.cached_tokens"),
        value: this.data.summary.total_cached_tokens,
        tooltip: i18n("discourse_ai.usage.stat_tooltips.cached_tokens"),
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
      cached: computedStyle.getPropertyValue("--chart-cached-color").trim(),
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
            label: i18n("discourse_ai.usage.net_request_tokens"),
            data: normalizedData.map(
              (row) => row.total_request_tokens - row.total_cached_tokens
            ),
            backgroundColor: colors.request,
          },
          {
            label: i18n("discourse_ai.usage.cached_request_tokens"),
            data: normalizedData.map((row) => row.total_cached_tokens),
            backgroundColor: colors.cached,
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

  get availableFeatures() {
    // when you switch we don't want the list to change
    // only when you switch durations
    this._cachedFeatures =
      this._cachedFeatures ||
      (this.data?.features || []).map((f) => ({
        id: f.feature_name,
        name: f.feature_name,
      }));

    return this._cachedFeatures;
  }

  get availableModels() {
    this._cachedModels =
      this._cachedModels ||
      (this.data?.models || []).map((m) => ({
        id: m.llm,
        name: m.llm,
      }));

    return this._cachedModels;
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
      case "month":
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
    this.fetchData();
  }

  @action
  onCustomDateClick() {
    this.isCustomDateActive = !this.isCustomDateActive;
    if (this.isCustomDateActive) {
      this.selectedPeriod = null;
    }
  }

  @action
  onDateChange() {
    this.isCustomDateActive = true;
    this.selectedPeriod = null;
    this.fetchData();
  }

  @action
  onChangeDateRange({ from, to }) {
    this._startDate = from;
    this._endDate = to;
  }

  @action
  onRefreshDateRange() {
    this.startDate = this._startDate;
    this.endDate = this._endDate;
    this.fetchData();
  }

  totalSpending(inputSpending, cachedSpending, outputSpending) {
    const total = inputSpending + cachedSpending + outputSpending;
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

              <DateTimeInputRange
                @from={{this.startDate}}
                @to={{this.endDate}}
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

        <ConditionalLoadingSpinner @condition={{this.loadingData}}>
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
                          <td>
                            {{this.totalSpending
                              feature.input_spending
                              feature.cached_input_spending
                              feature.output_spending
                            }}
                          </td>
                        </tr>
                      {{/each}}
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

                {{#if this.data.models.length}}
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
                      {{#each this.data.models as |model|}}
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
                              model.cached_input_spending
                              model.output_spending
                            }}
                          </td>
                        </tr>
                      {{/each}}
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
                  <table
                    class={{concatClass
                      "ai-usage__users-table"
                      (if (lt this.data.users.length 25) "-double-width")
                    }}
                  >
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
                      {{#each (this.takeUsers 0 24) as |user|}}
                        <tr class="ai-usage__users-row">
                          <td class="ai-usage__users-cell">
                            <div class="user-info">
                              <LinkTo
                                @route="user"
                                @model={{user.username}}
                                class="username"
                              >
                                {{avatar user imageSize="tiny"}}
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
                              user.cached_input_spending
                              user.output_spending
                            }}
                          </td>
                        </tr>
                      {{/each}}
                    </tbody>
                  </table>

                  {{#if (gt this.data.users.length 25)}}
                    <table class="ai-usage__users-table">
                      <thead>
                        <tr>
                          <th class="ai-usage__users-username">{{i18n
                              "discourse_ai.usage.username"
                            }}</th>
                          <th>{{i18n "discourse_ai.usage.usage_count"}}</th>
                          <th>{{i18n "discourse_ai.usage.total_tokens"}}</th>
                        </tr>
                      </thead>
                      <tbody>
                        {{#each (this.takeUsers 25 49) as |user|}}
                          <tr class="ai-usage__users-row">
                            <td class="ai-usage__users-cell">
                              <div class="user-info">
                                <LinkTo
                                  @route="user"
                                  @model={{user.username}}
                                  class="username"
                                >
                                  {{avatar user imageSize="tiny"}}
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
                          </tr>
                        {{/each}}
                      </tbody>
                    </table>
                  {{/if}}
                {{/if}}
              </:content>
            </AdminConfigAreaCard>
          </div>
        </ConditionalLoadingSpinner>
      </div>
    </div>
  </template>
}
