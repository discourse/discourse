{{#unless this.model.all_loaded}}
  {{hide-application-footer}}
{{/unless}}

{{#if this.model.logs}}
  <div class="group-manage-logs-controls">
    <GroupManageLogsFilter
      @clearFilter={{action "clearFilter"}}
      @value={{this.filters.action}}
      @type="action"
    />
    <GroupManageLogsFilter
      @clearFilter={{action "clearFilter"}}
      @value={{this.filters.acting_user}}
      @type="acting_user"
    />
    <GroupManageLogsFilter
      @clearFilter={{action "clearFilter"}}
      @value={{this.filters.target_user}}
      @type="target_user"
    />
    <GroupManageLogsFilter
      @clearFilter={{action "clearFilter"}}
      @value={{this.filters.subject}}
      @type="subject"
    />
  </div>

  <LoadMore
    @selector=".group-manage-logs .group-manage-logs-row"
    @action={{action "loadMore"}}
  >
    <table class="group-manage-logs">
      <thead>
        <th>{{i18n "groups.manage.logs.action"}}</th>
        <th>{{i18n "groups.manage.logs.acting_user"}}</th>
        <th>{{i18n "groups.manage.logs.target_user"}}</th>
        <th>{{i18n "groups.manage.logs.subject"}}</th>
        <th>{{i18n "groups.manage.logs.when"}}</th>
        <th></th>
      </thead>

      <tbody>
        {{#each this.model.logs as |logItem|}}
          <GroupManageLogsRow @log={{logItem}} @filters={{this.filters}} />
        {{/each}}
      </tbody>
    </table>
  </LoadMore>

  <ConditionalLoadingSpinner @condition={{this.loading}} />
{{else}}
  <div>{{i18n "groups.empty.logs"}}</div>
{{/if}}