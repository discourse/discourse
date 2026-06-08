import AdminReport from "discourse/admin/components/admin-report";
import PluginOutlet from "discourse/components/plugin-outlet";

export default <template>
  <div class="sections">
    <PluginOutlet
      @name="admin-dashboard-security-top"
      @connectorTagName="div"
    />

    <div class="main-section">
      {{#if @controller.currentUser.can_see_ip}}
        <AdminReport
          @dataSourceName="suspicious_logins"
          @filters={{@controller.lastWeekFilters}}
        />
      {{/if}}

      {{#if @controller.currentUser.admin}}
        <AdminReport
          @dataSourceName="admin_logins"
          @filters={{@controller.lastWeekFilters}}
        />
      {{/if}}

      <PluginOutlet
        @name="admin-dashboard-security-bottom"
        @connectorTagName="div"
      />
    </div>
  </div>
</template>
