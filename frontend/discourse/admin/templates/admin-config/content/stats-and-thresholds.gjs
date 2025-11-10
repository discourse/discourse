import AdminAreaSettings from "admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @area="stats_and_thresholds"
    @path="/admin/config/content/stats-and-thresholds"
    @filter={{@controller.filter}}
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @showBreadcrumb={{false}}
  />
</template>
