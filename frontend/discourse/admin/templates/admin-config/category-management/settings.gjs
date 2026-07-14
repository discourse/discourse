import AdminAreaSettings from "discourse/admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @area="categories"
    @path="/admin/config/category-management"
    @filter={{@controller.filter}}
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @showBreadcrumb={{false}}
  />
</template>
