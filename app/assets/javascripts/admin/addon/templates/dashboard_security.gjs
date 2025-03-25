<div class="sections">
  <PluginOutlet @name="admin-dashboard-security-top" @connectorTagName="div" />

  <div class="main-section">
    <AdminReport
      @dataSourceName="suspicious_logins"
      @filters={{this.lastWeekFilters}}
    />

    <AdminReport
      @dataSourceName="staff_logins"
      @filters={{this.lastWeekFilters}}
    />

    <PluginOutlet
      @name="admin-dashboard-security-bottom"
      @connectorTagName="div"
    />
  </div>
</div>