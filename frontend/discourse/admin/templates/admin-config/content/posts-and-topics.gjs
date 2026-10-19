import AdminAreaSettings from "discourse/admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @area="posts_and_topics"
    @filter={{@controller.filter}}
    @path="/admin/config/content/posts-and-topics"
    @showBreadcrumb={{false}}
  />
</template>
