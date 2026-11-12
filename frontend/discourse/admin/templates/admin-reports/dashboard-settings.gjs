import AdminAreaSettings from "discourse/admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @area="reports"
    @filter={{@controller.filter}}
    @path="/admin/reports/dashboard-settings"
  />
</template>
