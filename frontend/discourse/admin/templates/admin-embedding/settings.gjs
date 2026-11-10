import AdminAreaSettings from "discourse/admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @area="embedding"
    @filter={{@controller.filter}}
    @path="/admin/customize/embedding/settings"
  />
</template>
