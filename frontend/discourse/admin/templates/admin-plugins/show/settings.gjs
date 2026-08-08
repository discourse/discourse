import AdminAreaSettings from "discourse/admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @plugin={{@model.plugin.id}}
    @path="/admin/plugins/{{@model.plugin.name}}/settings"
    @filter={{@controller.filter}}
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
  />
</template>
