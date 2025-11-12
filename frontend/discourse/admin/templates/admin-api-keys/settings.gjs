import AdminAreaSettings from "discourse/admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @categories="user_api"
    @path="/admin/api/keys/settings"
    @filter={{@controller.filter}}
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
  />
</template>
