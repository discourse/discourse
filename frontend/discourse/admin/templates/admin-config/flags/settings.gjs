import AdminAreaSettings from "discourse/admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @area="flags"
    @filter={{@controller.filter}}
    @path="/admin/config/flags/settings"
  />
</template>
