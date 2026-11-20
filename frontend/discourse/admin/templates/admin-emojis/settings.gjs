import AdminAreaSettings from "discourse/admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @area="emojis"
    @filter={{@controller.filter}}
    @path="/admin/config/emoji/settings"
  />
</template>
