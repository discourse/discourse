import AdminAreaSettings from "admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @area="emojis"
    @path="/admin/config/emoji/settings"
    @filter={{@controller.filter}}
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
  />
</template>
