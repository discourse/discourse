import AdminAreaSettings from "discourse/admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @categories="user_api"
    @filter={{@controller.filter}}
    @path="/admin/api/keys/settings"
  />
</template>
