import AdminReport from "discourse/admin/components/admin-report";
import PluginOutlet from "discourse/components/plugin-outlet";

export default <template>
  <div class="sections">
    <PluginOutlet
      @connectorTagName="div"
      @name="admin-dashboard-security-top"
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
        @connectorTagName="div"
        @name="admin-dashboard-security-bottom"
      />
    </div>
  </div>
</template>
