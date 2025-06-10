import RouteTemplate from "ember-route-template";
import PluginOutlet from "discourse/components/plugin-outlet";
import getUrl from "discourse/helpers/get-url";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";
import AdminReport from "admin/components/admin-report";
import DashboardPeriodSelector from "admin/components/dashboard-period-selector";

export default RouteTemplate(
  <template>
    <div class="sections">
      <PluginOutlet
        @name="admin-dashboard-moderation-top"
        @connectorTagName="div"
      />

      {{#if @controller.isModeratorsActivityVisible}}
        <div class="moderators-activity section">
          <div class="section-title">
            <h2>
              <a href={{getUrl "/admin/reports/moderators_activity"}}>
                {{i18n "admin.dashboard.moderators_activity"}}
              </a>
            </h2>

            <DashboardPeriodSelector
              @period={{@controller.period}}
              @setPeriod={{@controller.setPeriod}}
              @startDate={{@controller.startDate}}
              @endDate={{@controller.endDate}}
              @setCustomDateRange={{@controller.setCustomDateRange}}
            />
          </div>

          <div class="section-body">
            <AdminReport
              @filters={{@controller.filters}}
              @showHeader={{false}}
              @dataSourceName="moderators_activity"
            />
          </div>
        </div>
      {{/if}}

      <div class="main-section">
        <AdminReport
          @dataSourceName="flags_status"
          @reportOptions={{@controller.flagsStatusOptions}}
          @filters={{@controller.lastWeekFilters}}
        />

        <AdminReport
          @dataSourceName="post_edits"
          @filters={{@controller.lastWeekFilters}}
        />

        <AdminReport
          @dataSourceName="user_flagging_ratio"
          @filters={{@controller.lastWeekFilters}}
          @reportOptions={{@controller.userFlaggingRatioOptions}}
        />

        <PluginOutlet
          @name="admin-dashboard-moderation-bottom"
          @connectorTagName="div"
          @outletArgs={{lazyHash filters=@controller.lastWeekFilters}}
        />
      </div>
    </div>
  </template>
);
