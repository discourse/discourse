import RouteTemplate from "ember-route-template";
import PluginOutlet from "discourse/components/plugin-outlet";
import AdminReport from "admin/components/admin-report";

export default RouteTemplate(
  <template>
    <div class="sections">
      <PluginOutlet
        @name="admin-dashboard-security-top"
        @connectorTagName="div"
      />

      <div class="main-section">
        <AdminReport
          @dataSourceName="suspicious_logins"
          @filters={{@controller.lastWeekFilters}}
        />

        <AdminReport
          @dataSourceName="staff_logins"
          @filters={{@controller.lastWeekFilters}}
        />

        <PluginOutlet
          @name="admin-dashboard-security-bottom"
          @connectorTagName="div"
        />
      </div>
    </div>
  </template>
);
