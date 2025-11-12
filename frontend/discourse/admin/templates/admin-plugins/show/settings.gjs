import AdminAreaSettings from "discourse/admin/components/admin-area-settings";

export default <template>
  <div
    class="content-body admin-plugin-config-area__settings admin-detail pull-left"
  >
    <AdminAreaSettings
      @plugin={{@model.plugin.id}}
      @path="/admin/plugins/{{@model.plugin.name}}/settings"
      @filter={{@controller.filter}}
      @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    />
  </div>
</template>
