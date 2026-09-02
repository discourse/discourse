import AdminAreaSettings from "discourse/admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @area="discourseconnect"
    @filter={{@controller.filter}}
    @path="/admin/config/login-and-authentication/discourse-connect"
    @showBreadcrumb={{false}}
  />
</template>
