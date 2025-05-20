import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import ConditionalLoadingSection from "discourse/components/conditional-loading-section";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import PluginOutlet from "discourse/components/plugin-outlet";
import basePath from "discourse/helpers/base-path";
import formatDate from "discourse/helpers/format-date";
import getUrl from "discourse/helpers/get-url";
import htmlSafe from "discourse/helpers/html-safe";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";
import AdminReport from "admin/components/admin-report";
import DashboardPeriodSelector from "admin/components/dashboard-period-selector";

export default RouteTemplate(
  <template>
    <ConditionalLoadingSpinner @condition={{@controller.isLoading}}>
      <PluginOutlet
        @name="admin-dashboard-general-top"
        @connectorTagName="div"
      />

      {{#if @controller.isCommunityHealthVisible}}
        <div class="community-health section">
          <div class="period-section">
            <div class="section-title">
              <h2>
                <a href={{getUrl "/admin/dashboard/reports"}}>
                  {{i18n "admin.dashboard.community_health"}}
                </a>
              </h2>

              <DashboardPeriodSelector
                @period={{@controller.period}}
                @setPeriod={{@controller.setPeriod}}
                @startDate={{@controller.startDate}}
                @endDate={{@controller.endDate}}
                @setCustomDateRange={{@controller.setCustomDateRange}}
                @onDateChange={{@controller.onDateChange}}
              />
            </div>

            <div class="section-body">
              <div class="charts">
                {{#if @controller.siteSettings.use_legacy_pageviews}}
                  <AdminReport
                    @dataSourceName="consolidated_page_views"
                    @forcedModes={{@controller.reportModes.stacked_chart}}
                    @filters={{@controller.filters}}
                  />
                {{else}}
                  <AdminReport
                    @dataSourceName="site_traffic"
                    @forcedModes={{@controller.reportModes.stacked_chart}}
                    @reportOptions={{@controller.siteTrafficOptions}}
                    @filters={{@controller.filters}}
                  />
                {{/if}}

                <AdminReport
                  @dataSourceName="signups"
                  @showTrend={{true}}
                  @forcedModes={{@controller.reportModes.chart}}
                  @filters={{@controller.filters}}
                />

                <AdminReport
                  @dataSourceName="topics"
                  @showTrend={{true}}
                  @forcedModes={{@controller.reportModes.chart}}
                  @filters={{@controller.filters}}
                />

                <AdminReport
                  @dataSourceName="posts"
                  @showTrend={{true}}
                  @forcedModes={{@controller.reportModes.chart}}
                  @filters={{@controller.filters}}
                />

                <AdminReport
                  @dataSourceName="dau_by_mau"
                  @showTrend={{true}}
                  @forcedModes={{@controller.reportModes.chart}}
                  @filters={{@controller.filters}}
                />

                <AdminReport
                  @dataSourceName="daily_engaged_users"
                  @showTrend={{true}}
                  @forcedModes={{@controller.reportModes.chart}}
                  @filters={{@controller.filters}}
                />

                <AdminReport
                  @dataSourceName="new_contributors"
                  @showTrend={{true}}
                  @forcedModes={{@controller.reportModes.chart}}
                  @filters={{@controller.filters}}
                />
              </div>
            </div>
          </div>
        </div>
      {{/if}}

      <div class="section-columns">
        <div class="section-column">
          {{#if @controller.isActivityMetricsVisible}}
            {{#if @controller.activityMetrics.length}}
              <div class="admin-report activity-metrics">
                <div class="header">
                  <ul class="breadcrumb">
                    <li class="item report">
                      <LinkTo @route="adminReports" class="report-url">
                        {{i18n "admin.dashboard.activity_metrics"}}
                      </LinkTo>
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

                    {{#each @controller.activityMetrics as |metric|}}
                      <AdminReport
                        @showHeader={{false}}
                        @filters={{@controller.activityMetricsFilters}}
                        @forcedModes={{@controller.reportModes.counters}}
                        @dataSourceName={{metric}}
                      />
                    {{/each}}
                  </div>
                </div>
              </div>
            {{/if}}
          {{/if}}

          <div class="user-metrics">
            <ConditionalLoadingSection @isLoading={{@controller.isLoading}}>
              <AdminReport
                @forcedModes={{@controller.reportModes.inline_table}}
                @dataSourceName="users_by_type"
              />

              <AdminReport
                @forcedModes={{@controller.reportModes.inline_table}}
                @dataSourceName="users_by_trust_level"
              />
            </ConditionalLoadingSection>
          </div>

          <div class="misc">
            <AdminReport
              @forcedModes={{@controller.reportModes.storage_stats}}
              @dataSourceName="storage_stats"
              @showHeader={{false}}
            />

            <div class="last-dashboard-update">
              <div>
                <h4>{{i18n "admin.dashboard.last_updated"}} </h4>
                <p>{{formatDate
                    @controller.model.attributes.updated_at
                    leaveAgo="true"
                  }}</p>
              </div>
              {{#if @controller.model.attributes.discourse_updated_at}}
                <div>
                  <h4>{{i18n "admin.dashboard.discourse_last_updated"}} </h4>
                  <p>{{formatDate
                      @controller.model.attributes.discourse_updated_at
                      leaveAgo="true"
                    }}</p>
                  <LinkTo @route="admin.whatsNew" class="btn btn-default">
                    {{i18n "admin.dashboard.whats_new_in_discourse"}}
                  </LinkTo>
                </div>
              {{/if}}
            </div>
          </div>
        </div>

        {{#if @controller.isSearchReportsVisible}}
          <div class="section-column">
            <AdminReport
              @filters={{@controller.topReferredTopicsFilters}}
              @dataSourceName="top_referred_topics"
              @reportOptions={{@controller.topReferredTopicsOptions}}
            />

            <AdminReport
              @dataSourceName="trending_search"
              @reportOptions={{@controller.trendingSearchOptions}}
              @filters={{@controller.trendingSearchFilters}}
              @isEnabled={{@controller.logSearchQueriesEnabled}}
              @disabledLabel={{@controller.trendingSearchDisabledLabel}}
            />
            {{htmlSafe
              (i18n
                "admin.dashboard.reports.trending_search.more"
                basePath=(basePath)
              )
            }}
          </div>
        {{/if}}
      </div>

      <PluginOutlet
        @name="admin-dashboard-general-bottom"
        @connectorTagName="div"
        @outletArgs={{lazyHash filters=@controller.filters}}
      />
    </ConditionalLoadingSpinner>
  </template>
);
