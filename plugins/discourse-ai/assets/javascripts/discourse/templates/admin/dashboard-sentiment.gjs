import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import AdminReport from "admin/components/admin-report";
import DashboardPeriodSelector from "admin/components/dashboard-period-selector";
import DTooltip from "float-kit/components/d-tooltip";

export default RouteTemplate(
  <template>
    <div class="sentiment section">
      <div class="period-section">
        <div class="section-title">
          <h2 id="sentiment-heading">
            {{i18n "discourse_ai.sentiments.dashboard.title"}}
          </h2>

          <DashboardPeriodSelector
            @period={{@controller.period}}
            @setPeriod={{@controller.setPeriod}}
            @startDate={{@controller.startDate}}
            @endDate={{@controller.endDate}}
            @setCustomDateRange={{@controller.setCustomDateRange}}
          />
        </div>
      </div>

      <div class="section-body">
        <div class="charts">
          <AdminReport
            @dataSourceName="overall_sentiment"
            @filters={{@controller.filters}}
            @showHeader={{true}}
          />
          <div class="admin-report activity-metrics">
            <div class="header">
              <ul class="breadcrumb">
                <li class="item report">
                  <LinkTo @route="adminReports" class="report-url">
                    {{i18n "admin.dashboard.emotion.title"}}
                  </LinkTo>
                  <DTooltip @interactive="true">
                    <:trigger>
                      {{icon "circle-question"}}
                    </:trigger>
                    <:content>
                      <span>{{i18n
                          "admin.dashboard.emotion.description"
                        }}</span>
                    </:content>
                  </DTooltip>
                </li>
              </ul>
            </div>
            <div class="report-body">
              <div class="counters-list">
                <div class="counters-header">
                  <div class="counters-cell"></div>
                  <div class="counters-cell">{{i18n
                      "admin.dashboard.reports.today"
                    }}</div>
                  <div class="counters-cell">{{i18n
                      "admin.dashboard.reports.yesterday"
                    }}</div>
                  <div class="counters-cell">{{i18n
                      "admin.dashboard.reports.last_7_days"
                    }}</div>
                  <div class="counters-cell">{{i18n
                      "admin.dashboard.reports.last_30_days"
                    }}</div>
                </div>
                {{#each @controller.emotions as |metric|}}
                  <AdminReport
                    @showHeader={{false}}
                    @filters={{@controller.emotionFilters}}
                    @forcedModes="emotion"
                    @dataSourceName="emotion_{{metric}}"
                  />
                {{/each}}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </template>
);
