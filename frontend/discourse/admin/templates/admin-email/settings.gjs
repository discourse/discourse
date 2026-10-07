import AdminAreaSettings from "discourse/admin/components/admin-area-settings";

export default <template>
  <div class="admin-config-page__main-area">
    <AdminAreaSettings
      @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
      @area="email"
      @filter={{@controller.filter}}
      @path="/admin/config/email"
      @showBreadcrumb={{false}}
    />
  </div>
</template>
