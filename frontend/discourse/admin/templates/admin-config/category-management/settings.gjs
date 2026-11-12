import AdminAreaSettings from "discourse/admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @area="categories"
    @filter={{@controller.filter}}
    @path="/admin/config/category-management"
    @showBreadcrumb={{false}}
  />
</template>
