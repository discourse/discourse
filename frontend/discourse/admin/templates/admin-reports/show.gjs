import AdminReport from "discourse/admin/components/admin-report";
import BackButton from "discourse/components/back-button";
import routeAction from "discourse/helpers/route-action";
import getUrl from "discourse/lib/get-url";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if @controller.dashboardReturnUrl}}
    <a
      href={{getUrl @controller.dashboardReturnUrl}}
      class="btn btn-transparent back-button"
    >
      {{dIcon "chevron-left"}}
      {{i18n "admin.reports.back_to_dashboard"}}
    </a>
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
