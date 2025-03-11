import RouteTemplate from 'ember-route-template'
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import GroupManageLogsFilter from "discourse/components/group-manage-logs-filter";
import LoadMore from "discourse/components/load-more";
import i18n from "discourse/helpers/i18n";
import GroupManageLogsRow from "discourse/components/group-manage-logs-row";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
export default RouteTemplate(<template>{{#unless @controller.model.all_loaded}}
  {{hideApplicationFooter}}
{{/unless}}

{{#if @controller.model.logs}}
  <div class="group-manage-logs-controls">
    <GroupManageLogsFilter @clearFilter={{action "clearFilter"}} @value={{@controller.filters.action}} @type="action" />
    <GroupManageLogsFilter @clearFilter={{action "clearFilter"}} @value={{@controller.filters.acting_user}} @type="acting_user" />
    <GroupManageLogsFilter @clearFilter={{action "clearFilter"}} @value={{@controller.filters.target_user}} @type="target_user" />
    <GroupManageLogsFilter @clearFilter={{action "clearFilter"}} @value={{@controller.filters.subject}} @type="subject" />
  </div>

  <LoadMore @selector=".group-manage-logs .group-manage-logs-row" @action={{action "loadMore"}}>
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
        {{#each @controller.model.logs as |logItem|}}
          <GroupManageLogsRow @log={{logItem}} @filters={{@controller.filters}} />
        {{/each}}
      </tbody>
    </table>
  </LoadMore>

  <ConditionalLoadingSpinner @condition={{@controller.loading}} />
{{else}}
  <div>{{i18n "groups.empty.logs"}}</div>
{{/if}}</template>)