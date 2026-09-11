import AdminAreaSettings from "discourse/admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @categories="backups"
    @filter={{@controller.filter}}
    @path="/admin/backups/settings"
  />
</template>
