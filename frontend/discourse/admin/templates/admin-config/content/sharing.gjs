import AdminAreaSettings from "discourse/admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @area="sharing"
    @filter={{@controller.filter}}
    @path="/admin/config/content/sharing"
    @showBreadcrumb={{false}}
  />
</template>
