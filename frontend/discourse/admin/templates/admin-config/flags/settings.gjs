import AdminAreaSettings from "admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @area="flags"
    @path="/admin/config/flags/settings"
    @filter={{@controller.filter}}
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
  />
</template>
