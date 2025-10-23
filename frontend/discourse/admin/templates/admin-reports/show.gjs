import RouteTemplate from "ember-route-template";
import BackButton from "discourse/components/back-button";
import routeAction from "discourse/helpers/route-action";
import AdminReport from "admin/components/admin-report";

export default RouteTemplate(
  <template>
    <BackButton @route="adminReports" @label="admin.reports.back" />
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
);
