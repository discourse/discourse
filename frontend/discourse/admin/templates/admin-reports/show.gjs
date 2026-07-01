import AdminReport from "discourse/admin/components/admin-report";
import BackButton from "discourse/components/back-button";
import routeAction from "discourse/helpers/route-action";

export default <template>
  {{#if @controller.dashboardReturnQueryParams}}
    <BackButton
      @route="admin.dashboard.general"
      @query={{@controller.dashboardReturnQueryParams}}
      @label="admin.reports.back_to_dashboard"
    />
  {{else}}
    <BackButton @route="adminReports" @label="admin.reports.back" />
  {{/if}}
  <div class="admin-container admin-config-page__main-area">
    <div class="admin-config-area">
      <AdminReport
        @dataSourceName={{@controller.model.type}}
        @filters={{@controller.model}}
        @reportOptions={{@controller.reportOptions}}
        @showFilteringUI={{true}}
        @showDescriptionInTooltip={{false}}
        @onRefresh={{routeAction "onParamsChange"}}
      />
    </div>
  </div>
</template>
