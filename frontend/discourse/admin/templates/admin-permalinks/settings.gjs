import AdminAreaSettings from "discourse/admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @area="permalinks"
    @filter={{@controller.filter}}
    @path="/admin/config/permalinks/settings"
  />
</template>
