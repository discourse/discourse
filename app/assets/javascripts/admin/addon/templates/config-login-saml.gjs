import RouteTemplate from "ember-route-template";
import AdminAreaSettings from "admin/components/admin-area-settings";

export default RouteTemplate(
  <template>
    <AdminAreaSettings
      @area="saml"
      @path="/admin/config/login-and-authentication/saml"
      @filter={{@controller.filter}}
      @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
      @showBreadcrumb={{false}}
    />
  </template>
);
