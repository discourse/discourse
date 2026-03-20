import { concat, fn } from "@ember/helper";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import AdminReport from "discourse/admin/components/admin-report";
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

<template>
  <div
    class={{dConcatClass "admin-report" @report.reportClasses}}
    {{didUpdate @report.fetchOrRender @filters.startDate @filters.endDate}}
  >
    {{#unless @report.isHidden}}
      <DConditionalLoadingSection @isLoading={{@report.isLoading}}>
        {{#if
          (and @report.siteSettings.reporting_improvements @report.model.legacy)
        }}
          <div class="alert alert-info">
            {{dIcon "triangle-exclamation"}}
            <span>{{i18n "admin.reports.legacy_warning"}}</span>
          </div>
        {{/if}}
        {{#if @report.showHeader}}
          <div class="header">
            {{#unless @report.showNotFoundError}}
              <DPageSubheader
                @titleLabel={{@report.model.title}}
                @titleUrl={{@report.model.reportUrl}}
                @descriptionLabel={{unless
                  @report.showDescriptionInTooltip
                  @report.model.description
                }}
                @learnMoreUrl={{@report.model.description_link}}
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

        <div class="body">
          <div class="main">
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
                    {{dIcon "temperature-three-quarters"}}
                    <span>{{@report.rateLimitationString}}</span>
                  </div>
                {{else}}
                  <div class="alert alert-info report-alert no-data">
                    {{dIcon "chart-pie"}}
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
            <div class="filters">
              {{#if @report.showModes}}
                <div class="modes">
                  {{#each @report.displayedModes as |displayedMode|}}
                    <DButton
                      @action={{fn @report.onChangeMode displayedMode.mode}}
                      @icon={{displayedMode.icon}}
                      class={{displayedMode.cssClass}}
                    />
                  {{/each}}
                </div>
              {{/if}}

              {{#if @report.isChartMode}}
                {{#if @report.model.average}}
                  <span class="average-chart">
                    {{i18n "admin.dashboard.reports.average_chart_label"}}
                  </span>
                {{/if}}
                <div class="chart-groupings">
                  {{#each @report.chartGroupings as |chartGrouping|}}
                    <DButton
                      @label={{chartGrouping.label}}
                      @action={{fn @report.changeGrouping chartGrouping.id}}
                      @disabled={{chartGrouping.disabled}}
                      class={{chartGrouping.class}}
                    />
                  {{/each}}
                </div>
              {{/if}}

              {{#if @report.showDatesOptions}}
                <div class="control">
                  <span class="label">
                    {{i18n "admin.dashboard.reports.dates"}}
                  </span>

                  <div class="input">
                    <DDateTimeInputRange
                      @from={{@report.startDate}}
                      @to={{@report.endDate}}
                      @onChange={{@report.onChangeDateRange}}
                      @showFromTime={{false}}
                      @showToTime={{false}}
                    />
                  </div>
                </div>
              {{/if}}

              {{#each @report.model.available_filters as |filter|}}
                <div class="control">
                  <span class="label">
                    {{i18n
                      (concat
                        "admin.dashboard.reports.filters." filter.id ".label"
                      )
                    }}
                  </span>

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
                      class="refresh-report-btn btn-primary"
                    />
                  </div>
                </div>
              {{/if}}
            </div>
          {{/if}}
        </div>
      </DConditionalLoadingSection>
    {{/unless}}
  </div>
</template>
