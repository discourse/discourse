import AdminAreaSettings from "admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @area="categories_and_tags"
    @path="/admin/config/content/categories-and-tags"
    @filter={{@controller.filter}}
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @showBreadcrumb={{false}}
  />
</template>
