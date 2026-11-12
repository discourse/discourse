import AdminAreaSettings from "discourse/admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @area="badges"
    @filter={{@controller.filter}}
    @path="/admin/badges/settings"
  />
</template>
