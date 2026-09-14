import AdminAreaSettings from "discourse/admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @area="mcp"
    @filter={{@controller.filter}}
    @path="/admin/config/mcp"
    @showBreadcrumb={{false}}
  />
</template>
