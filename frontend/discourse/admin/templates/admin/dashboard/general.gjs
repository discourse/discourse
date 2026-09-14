import { LinkTo } from "@ember/routing";
import { trustHTML } from "@ember/template";
import AdminReport from "discourse/admin/components/admin-report";
import DashboardPeriodSelector from "discourse/admin/components/dashboard-period-selector";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import getUrl from "discourse/lib/get-url";
import DConditionalLoadingSection from "discourse/ui-kit/d-conditional-loading-section";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import dBasePath from "discourse/ui-kit/helpers/d-base-path";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import { i18n } from "discourse-i18n";

export default <template>
  <DConditionalLoadingSpinner @condition={{@controller.isLoading}}>
    <PluginOutlet @connectorTagName="div" @name="admin-dashboard-general-top" />

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
              @endDate={{@controller.endDate}}
              @period={{@controller.period}}
              @setCustomDateRange={{@controller.setCustomDateRange}}
              @setPeriod={{@controller.setPeriod}}
              @startDate={{@controller.startDate}}
            />
          </div>

          <div class="section-body">
            <div class="charts">
              {{#if @controller.siteSettings.use_legacy_pageviews}}
                <AdminReport
                  @dataSourceName="consolidated_page_views"
                  @filters={{@controller.filters}}
                  @forcedModes={{@controller.reportModes.stacked_chart}}
                />
              {{else}}
                <AdminReport
                  @dataSourceName="site_traffic"
                  @filters={{@controller.filters}}
                  @forcedModes={{@controller.reportModes.stacked_chart}}
                  @reportOptions={{@controller.siteTrafficOptions}}
                />
              {{/if}}

              <AdminReport
                @dataSourceName="signups"
                @filters={{@controller.filters}}
                @forcedModes={{@controller.reportModes.chart}}
                @showTrend={{true}}
              />

              <AdminReport
                @dataSourceName="topics"
                @filters={{@controller.filters}}
                @forcedModes={{@controller.reportModes.chart}}
                @showTrend={{true}}
              />

              <AdminReport
                @dataSourceName="posts"
                @filters={{@controller.filters}}
                @forcedModes={{@controller.reportModes.chart}}
                @showTrend={{true}}
              />

              <AdminReport
                @dataSourceName="dau_by_mau"
                @filters={{@controller.filters}}
                @forcedModes={{@controller.reportModes.chart}}
                @showTrend={{true}}
              />

              <AdminReport
                @dataSourceName="daily_engaged_users"
                @filters={{@controller.filters}}
                @forcedModes={{@controller.reportModes.chart}}
                @showTrend={{true}}
              />

              <AdminReport
                @dataSourceName="new_contributors"
                @filters={{@controller.filters}}
                @forcedModes={{@controller.reportModes.chart}}
                @showTrend={{true}}
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
                    <LinkTo class="report-url" @route="adminReports">
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
                      @dataSourceName={{metric}}
                      @filters={{@controller.activityMetricsFilters}}
                      @forcedModes={{@controller.reportModes.counters}}
                      @showHeader={{false}}
                    />
                  {{/each}}
                </div>
              </div>
            </div>
          {{/if}}
        {{/if}}

        <div class="user-metrics">
          <DConditionalLoadingSection @isLoading={{@controller.isLoading}}>
            <AdminReport
              @dataSourceName="users_by_type"
              @forcedModes={{@controller.reportModes.inline_table}}
            />

            <AdminReport
              @dataSourceName="users_by_trust_level"
              @forcedModes={{@controller.reportModes.inline_table}}
            />
          </DConditionalLoadingSection>
        </div>

        <div class="misc">
          <AdminReport
            @dataSourceName="storage_stats"
            @forcedModes={{@controller.reportModes.storage_stats}}
            @showHeader={{false}}
          />

          <div class="last-dashboard-update">
            <div>
              <h4>{{i18n "admin.dashboard.last_updated"}} </h4>
              <p>{{dFormatDate
                  @controller.model.attributes.updated_at
                  leaveAgo="true"
                }}</p>
            </div>
            {{#if @controller.model.attributes.discourse_updated_at}}
              <div>
                <h4>{{i18n "admin.dashboard.discourse_last_updated"}} </h4>
                <p>{{dFormatDate
                    @controller.model.attributes.discourse_updated_at
                    leaveAgo="true"
                  }}</p>
                <LinkTo class="btn btn-default" @route="admin.whatsNew">
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
            @dataSourceName="top_referred_topics"
            @filters={{@controller.topReferredTopicsFilters}}
            @reportOptions={{@controller.topReferredTopicsOptions}}
          />

          <AdminReport
            @dataSourceName="trending_search"
            @disabledLabel={{@controller.trendingSearchDisabledLabel}}
            @filters={{@controller.trendingSearchFilters}}
            @isEnabled={{@controller.logSearchQueriesEnabled}}
            @reportOptions={{@controller.trendingSearchOptions}}
          />
          {{trustHTML
            (i18n
              "admin.dashboard.reports.trending_search.more"
              basePath=(dBasePath)
            )
          }}
        </div>
      {{/if}}
    </div>

    <PluginOutlet
      @connectorTagName="div"
      @name="admin-dashboard-general-bottom"
      @outletArgs={{lazyHash filters=@controller.filters}}
    />
  </DConditionalLoadingSpinner>
</template>
