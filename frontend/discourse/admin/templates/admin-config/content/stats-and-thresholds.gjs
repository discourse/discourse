import AdminAreaSettings from "discourse/admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @area="stats_and_thresholds"
    @filter={{@controller.filter}}
    @path="/admin/config/content/stats-and-thresholds"
    @showBreadcrumb={{false}}
  />
</template>
