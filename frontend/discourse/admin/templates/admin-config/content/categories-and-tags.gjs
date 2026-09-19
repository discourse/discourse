import AdminAreaSettings from "discourse/admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @area="categories_and_tags"
    @filter={{@controller.filter}}
    @path="/admin/config/content/categories-and-tags"
    @showBreadcrumb={{false}}
  />
</template>
