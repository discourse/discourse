import AdminAreaSettings from "discourse/admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @filter={{@controller.filter}}
    @path="/admin/plugins/{{@model.plugin.name}}/settings"
    @plugin={{@model.plugin.id}}
  />
</template>
