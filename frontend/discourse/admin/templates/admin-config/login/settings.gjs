import AdminAreaSettings from "discourse/admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @area="login"
    @filter={{@controller.filter}}
    @path="/admin/config/login-and-authentication"
  />
</template>
