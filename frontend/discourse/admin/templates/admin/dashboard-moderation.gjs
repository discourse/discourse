import AdminReport from "discourse/admin/components/admin-report";
import DashboardPeriodSelector from "discourse/admin/components/dashboard-period-selector";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import getUrl from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="sections">
    <PluginOutlet
      @connectorTagName="div"
      @name="admin-dashboard-moderation-top"
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
            @endDate={{@controller.endDate}}
            @period={{@controller.period}}
            @setCustomDateRange={{@controller.setCustomDateRange}}
            @setPeriod={{@controller.setPeriod}}
            @startDate={{@controller.startDate}}
          />
        </div>

        <div class="section-body">
          <AdminReport
            @dataSourceName="moderators_activity"
            @filters={{@controller.filters}}
            @showHeader={{false}}
          />
        </div>
      </div>
    {{/if}}

    <div class="main-section">
      <AdminReport
        @dataSourceName="flags_status"
        @filters={{@controller.lastWeekFilters}}
        @reportOptions={{@controller.flagsStatusOptions}}
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
        @connectorTagName="div"
        @name="admin-dashboard-moderation-bottom"
        @outletArgs={{lazyHash filters=@controller.lastWeekFilters}}
      />
    </div>
  </div>
</template>
