import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";
import AdminBackupsLogs from "admin/components/admin-backups-logs";

export default RouteTemplate(
  <template>
    <DBreadcrumbsItem
      @path="/admin/backups/logs"
      @label={{i18n "admin.backups.menu.logs"}}
    />

    <AdminBackupsLogs
      @logs={{@controller.logs}}
      @status={{@controller.status}}
    />
  </template>
);
