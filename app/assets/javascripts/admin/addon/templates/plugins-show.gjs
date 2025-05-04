import RouteTemplate from "ember-route-template";
import AdminPluginConfigPage from "admin/components/admin-plugin-config-page";

export default RouteTemplate(
  <template>
    <AdminPluginConfigPage @plugin={{@controller.model}}>
      {{outlet}}
    </AdminPluginConfigPage>
  </template>
);
