import AdminAreaSettings from "discourse/admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @categories="groups"
    @filter={{@controller.filter}}
    @path="/admin/groups/settings"
  />
</template>
