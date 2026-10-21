import { concat, fn } from "@ember/helper";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import AdminReport from "discourse/admin/components/admin-report";
import AdminReportRelatedItems from "discourse/admin/components/admin-report-related-items";
import DSegmentedControl from "discourse/components/d-segmented-control";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { and } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSection from "discourse/ui-kit/d-conditional-loading-section";
import DDateTimeInputRange from "discourse/ui-kit/d-date-time-input-range";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dNumber from "discourse/ui-kit/helpers/d-number";
import { i18n } from "discourse-i18n";

export default <template>
  <div
    class={{dConcatClass "admin-report" @report.reportClasses}}
    {{didUpdate
      @report.fetchOrRender
      @filters.startDate
      @filters.endDate
      @report.preloadedData
    }}
  >
    {{#unless @report.isHidden}}
      <DConditionalLoadingSection @isLoading={{@report.isLoading}}>
        {{#if @report.showHeader}}
          {{#if @report.model.legacy}}
            <div class="alert alert-info">
              {{dIcon "triangle-exclamation"}}
              <span>{{i18n "admin.reports.legacy_warning"}}</span>
            </div>
          {{/if}}
          <div class="header">
            {{#unless @report.showNotFoundError}}
              <DPageSubheader
                @learnMoreUrl={{@report.model.description_link}}
                @titleLabel={{@report.model.title}}
                @titleUrl={{@report.model.reportUrl}}
              />

              {{#if @report.showDescriptionInTooltip}}
                {{#if @report.model.description}}
                  <DTooltip
                    @interactive={{@report.model.description_link.length}}
                  >
                    <:trigger>
                      {{dIcon "circle-question"}}
                    </:trigger>
                    <:content>
                      {{#if @report.model.description_link}}
                        <a
                          class="info"
                          href={{@report.model.description_link}}
                          rel="noopener noreferrer"
                          target="_blank"
                        >
                          {{@report.model.description}}
                        </a>
                      {{else}}
                        <span>{{@report.model.description}}</span>
                      {{/if}}
                    </:content>
                  </DTooltip>
                {{/if}}
              {{/if}}
            {{/unless}}

            {{#if @report.shouldDisplayTrend}}
              <div class="trend {{@report.model.trend}}">
                <span class="value" title={{@report.model.trendTitle}}>
                  {{#if @report.model.average}}
                    {{dNumber @report.model.currentAverage}}{{#if
                      @report.model.percent
                    }}%{{/if}}
                  {{else}}
                    {{dNumber @report.model.currentTotal noTitle="true"}}{{#if
                      @report.model.percent
                    }}%{{/if}}
                  {{/if}}

                  {{#if @report.model.trendIcon}}
                    {{dIcon @report.model.trendIcon class="icon"}}
                  {{/if}}
                </span>
              </div>
            {{/if}}
          </div>
        {{/if}}

        <div class="chart__wrapper">
          {{#if @report.showFilteringUI}}
            <div class="chart__filters">
              {{#if @report.isChartMode}}

                <DSegmentedControl
                  class="chart-groupings"
                  @items={{@report.chartGroupingSegmentItems}}
                  @label="admin.dashboard.reports.chart_group_period"
                  @name="chart-grouping-{{@report.model.type}}"
                  @onSelect={{@report.changeGrouping}}
                  @value={{@report.options.chartGrouping}}
                />
              {{/if}}

              {{#if @report.showDatesOptions}}
                <div class="chart__dates">
                  <DDateTimeInputRange
                    @from={{@report.startDate}}
                    @onChange={{@report.onChangeDateRange}}
                    @showFromTime={{false}}
                    @showToTime={{false}}
                    @to={{@report.endDate}}
                  />
                </div>
              {{/if}}

              <div class="chart__additional-filters">
                {{#each @report.model.available_filters as |filter|}}
                  <div
                    class={{dConcatClass
                      "chart__filter"
                      (concat "--" filter.id)
                    }}
                  >
                    <div class="input">
                      {{component
                        (@report.reportFilterComponent filter)
                        model=@report.model
                        filter=filter
                        applyFilter=@report.applyFilter
                      }}
                    </div>
                  </div>
                {{/each}}
              </div>

            </div>
          {{/if}}
          <div class="chart__body">
            {{#if (and @report.model.average @report.showFilteringUI)}}
              <div class="average-chart">
                {{i18n "admin.dashboard.reports.average_chart_label"}}
              </div>
            {{/if}}
            {{#if @report.showError}}
              {{#if @report.showTimeoutError}}
                <div class="alert alert-error report-alert timeout">
                  {{dIcon "triangle-exclamation"}}
                  <span>{{i18n "admin.dashboard.timeout_error"}}</span>
                </div>
              {{/if}}

              {{#if @report.showExceptionError}}
                <div class="alert alert-error report-alert exception">
                  {{dIcon "triangle-exclamation"}}
                  <span>{{i18n "admin.dashboard.exception_error"}}</span>
                </div>
              {{/if}}

              {{#if @report.showNotFoundError}}
                <div class="alert alert-error report-alert not-found">
                  {{dIcon "triangle-exclamation"}}
                  <span>{{i18n "admin.dashboard.not_found_error"}}</span>
                </div>
              {{/if}}
            {{else}}
              {{#if @report.hasData}}
                {{#if @report.currentMode}}
                  {{component
                    @report.modeComponent
                    model=@report.model
                    hasRelatedItems=@report.hasRelatedItems
                    options=@report.options
                    reportType=@report.model.type
                    reportFilters=@report.reportFilters
                  }}

                  {{#if @report.model.relatedReport}}
                    <AdminReport
                      @dataSourceName={{@report.model.relatedReport.type}}
                      @showFilteringUI={{false}}
                    />
                  {{/if}}
                {{/if}}
              {{else}}
                {{#if @report.rateLimitationString}}
                  <div class="alert alert-error report-alert rate-limited">
                    {{dIcon "temperature-three-quarters"}}
                    <span>{{@report.rateLimitationString}}</span>
                  </div>
                {{else}}
                  <div class="alert alert-info report-alert no-data">
                    {{dIcon "chart-pie"}}
                    {{#if @report.model.reportUrl}}
                      <a class="report-url" href={{@report.model.reportUrl}}>
                        <span>
                          {{#if @report.model.title}}
                            {{@report.model.title}}
                            —
                          {{/if}}
                          {{i18n "admin.dashboard.reports.no_data"}}
                        </span>
                      </a>
                    {{else}}
                      <span>{{i18n "admin.dashboard.reports.no_data"}}</span>
                    {{/if}}
                  </div>
                {{/if}}
              {{/if}}
            {{/if}}
          </div>
          {{#if @report.showFilteringUI}}
            <div class="chart__actions">
              {{#if @report.showModes}}
                <div class="chart__modes">
                  {{#each @report.displayedModes as |displayedMode|}}
                    <DButton
                      class={{displayedMode.cssClass}}
                      @action={{fn @report.onChangeMode displayedMode.mode}}
                      @icon={{displayedMode.icon}}
                    />
                  {{/each}}
                </div>
              {{/if}}
              <div class="control">
                <div class="input">
                  <DButton
                    class="btn-default export-csv-btn"
                    @action={{@report.exportCsv}}
                    @icon="download"
                    @label="admin.export_csv.button_text"
                  />
                </div>
              </div>

              {{#if @report.showRefresh}}
                <div class="control">
                  <div class="input">
                    <DButton
                      class="refresh-report-btn btn-default"
                      @action={{@report.refreshReport}}
                      @icon="arrows-rotate"
                      @label="admin.dashboard.reports.refresh_report"
                    />
                  </div>
                </div>
              {{/if}}
            </div>
          {{/if}}
        </div>
        {{#if (and @report.isChartMode @report.hasRelatedItems)}}
          <AdminReportRelatedItems
            @endDate={{@report.endDate}}
            @relatedItems={{@report.model.related_items}}
            @relatedItemsTotals={{@report.model.related_items_totals}}
            @startDate={{@report.startDate}}
            @type={{@report.model.type}}
          />
        {{/if}}
      </DConditionalLoadingSection>
    {{/unless}}
  </div>
</template>
