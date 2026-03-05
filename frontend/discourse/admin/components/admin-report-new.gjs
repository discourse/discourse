import { concat, fn } from "@ember/helper";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import AdminReport from "discourse/admin/components/admin-report";
import ConditionalLoadingSection from "discourse/components/conditional-loading-section";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import DateTimeInputRange from "discourse/components/date-time-input-range";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import number from "discourse/helpers/number";
import { and } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

<template>
  <div
    class={{concatClass "admin-report" @report.reportClasses}}
    {{didUpdate @report.fetchOrRender @filters.startDate @filters.endDate}}
  >
    {{#unless @report.isHidden}}
      <ConditionalLoadingSection @isLoading={{@report.isLoading}}>
        {{#if
          (and @report.siteSettings.reporting_improvements @report.model.legacy)
        }}
          <div class="alert alert-info">
            {{icon "triangle-exclamation"}}
            <span>{{i18n "admin.reports.legacy_warning"}}</span>
          </div>
        {{/if}}
        {{#if @report.showHeader}}
          <div class="header">
            {{#unless @report.showNotFoundError}}
              <DPageSubheader
                @titleLabel={{@report.model.title}}
                @titleUrl={{@report.model.reportUrl}}
                @learnMoreUrl={{@report.model.description_link}}
              />

              {{#if @report.showDescriptionInTooltip}}
                {{#if @report.model.description}}
                  <DTooltip
                    @interactive={{@report.model.description_link.length}}
                  >
                    <:trigger>
                      {{icon "circle-question"}}
                    </:trigger>
                    <:content>
                      {{#if @report.model.description_link}}
                        <a
                          target="_blank"
                          rel="noopener noreferrer"
                          href={{@report.model.description_link}}
                          class="info"
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
                    {{number @report.model.currentAverage}}{{#if
                      @report.model.percent
                    }}%{{/if}}
                  {{else}}
                    {{number @report.model.currentTotal noTitle="true"}}{{#if
                      @report.model.percent
                    }}%{{/if}}
                  {{/if}}

                  {{#if @report.model.trendIcon}}
                    {{icon @report.model.trendIcon class="icon"}}
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

                <div
                  class="chart-groupings"
                  role="tablist"
                  aria-label={{i18n
                    "admin.dashboard.reports.chart_group_period"
                  }}
                >
                  {{#each @report.chartGroupings as |chartGrouping|}}
                    <DButton
                      @label={{chartGrouping.label}}
                      @action={{fn @report.changeGrouping chartGrouping.id}}
                      @disabled={{chartGrouping.disabled}}
                      class={{chartGrouping.class}}
                      role="tab"
                    />
                  {{/each}}
                </div>
              {{/if}}

              {{#if @report.showDatesOptions}}
                <div class="chart__dates">
                  <DateTimeInputRange
                    @from={{@report.startDate}}
                    @to={{@report.endDate}}
                    @onChange={{@report.onChangeDateRange}}
                    @showFromTime={{false}}
                    @showToTime={{false}}
                  />
                </div>
              {{/if}}

              <div class="chart__additional-filters">
                {{#each @report.model.available_filters as |filter|}}
                  <div
                    class={{concatClass
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
                  {{icon "triangle-exclamation"}}
                  <span>{{i18n "admin.dashboard.timeout_error"}}</span>
                </div>
              {{/if}}

              {{#if @report.showExceptionError}}
                <div class="alert alert-error report-alert exception">
                  {{icon "triangle-exclamation"}}
                  <span>{{i18n "admin.dashboard.exception_error"}}</span>
                </div>
              {{/if}}

              {{#if @report.showNotFoundError}}
                <div class="alert alert-error report-alert not-found">
                  {{icon "triangle-exclamation"}}
                  <span>{{i18n "admin.dashboard.not_found_error"}}</span>
                </div>
              {{/if}}
            {{else}}
              {{#if @report.hasData}}
                {{#if @report.currentMode}}
                  {{component
                    @report.modeComponent
                    model=@report.model
                    options=@report.options
                  }}

                  {{#if @report.model.relatedReport}}
                    <AdminReport
                      @showFilteringUI={{false}}
                      @dataSourceName={{@report.model.relatedReport.type}}
                    />
                  {{/if}}
                {{/if}}
              {{else}}
                {{#if @report.rateLimitationString}}
                  <div class="alert alert-error report-alert rate-limited">
                    {{icon "temperature-three-quarters"}}
                    <span>{{@report.rateLimitationString}}</span>
                  </div>
                {{else}}
                  <div class="alert alert-info report-alert no-data">
                    {{icon "chart-pie"}}
                    {{#if @report.model.reportUrl}}
                      <a href={{@report.model.reportUrl}} class="report-url">
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
                      @action={{fn @report.onChangeMode displayedMode.mode}}
                      @icon={{displayedMode.icon}}
                      class={{displayedMode.cssClass}}
                    />
                  {{/each}}
                </div>
              {{/if}}
              <div class="control">
                <div class="input">
                  <DButton
                    @action={{@report.exportCsv}}
                    @label="admin.export_csv.button_text"
                    @icon="download"
                    class="btn-default export-csv-btn"
                  />
                </div>
              </div>

              {{#if @report.showRefresh}}
                <div class="control">
                  <div class="input">
                    <DButton
                      @action={{@report.refreshReport}}
                      @label="admin.dashboard.reports.refresh_report"
                      @icon="arrows-rotate"
                      class="refresh-report-btn btn-default"
                    />
                  </div>
                </div>
              {{/if}}
            </div>
          {{/if}}
        </div>
      </ConditionalLoadingSection>
    {{/unless}}
  </div>
</template>
