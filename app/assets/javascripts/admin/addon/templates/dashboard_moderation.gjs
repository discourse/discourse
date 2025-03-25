<div class="sections">
  <PluginOutlet
    @name="admin-dashboard-moderation-top"
    @connectorTagName="div"
  />

  {{#if this.isModeratorsActivityVisible}}
    <div class="moderators-activity section">
      <div class="section-title">
        <h2>
          <a href={{get-url "/admin/reports/moderators_activity"}}>
            {{i18n "admin.dashboard.moderators_activity"}}
          </a>
        </h2>

        <DashboardPeriodSelector
          @period={{this.period}}
          @setPeriod={{this.setPeriod}}
          @startDate={{this.startDate}}
          @endDate={{this.endDate}}
          @setCustomDateRange={{this.setCustomDateRange}}
        />
      </div>

      <div class="section-body">
        <AdminReport
          @filters={{this.filters}}
          @showHeader={{false}}
          @dataSourceName="moderators_activity"
        />
      </div>
    </div>
  {{/if}}

  <div class="main-section">
    <AdminReport
      @dataSourceName="flags_status"
      @reportOptions={{this.flagsStatusOptions}}
      @filters={{this.lastWeekFilters}}
    />

    <AdminReport
      @dataSourceName="post_edits"
      @filters={{this.lastWeekFilters}}
    />

    <AdminReport
      @dataSourceName="user_flagging_ratio"
      @filters={{this.lastWeekFilters}}
      @reportOptions={{this.userFlaggingRatioOptions}}
    />

    <PluginOutlet
      @name="admin-dashboard-moderation-bottom"
      @connectorTagName="div"
      @outletArgs={{hash filters=this.lastWeekFilters}}
    />
  </div>
</div>