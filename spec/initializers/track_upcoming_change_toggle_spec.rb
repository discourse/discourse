# frozen_string_literal: true

RSpec.describe "Upcoming change toggles" do
  describe "when a plugin is enabled" do
    let(:plugin) do
      Plugin::Instance.new.tap do |instance|
        instance.metadata = Plugin::Metadata.new.tap { |m| m.name = "my-plugin" }
        instance.enabled_site_setting(:enable_upload_debug_mode)
      end
    end

    before do
      SiteSetting.promote_upcoming_changes_on_status = :beta

      mock_upcoming_change_metadata(
        {
          show_user_menu_avatars: {
            impact: "feature,all_members",
            status: :stable,
            impact_type: "feature",
            impact_role: "all_members",
          },
          enable_experimental_admin_ui_grouped_filters: {
            impact: "feature,admins",
            status: :stable,
            impact_type: "feature",
            impact_role: "admins",
          },
        },
      )

      Discourse.plugins_by_name["my-plugin"] = plugin
      SiteSetting.plugins[:enable_upload_debug_mode] = "my-plugin"
      SiteSetting.plugins[:show_user_menu_avatars] = "my-plugin"

      UpcomingChangeEvent.delete_all
    end

    after do
      Discourse.plugins_by_name.delete("my-plugin")
      SiteSetting.plugins.delete(:enable_upload_debug_mode)
      SiteSetting.plugins.delete(:show_user_menu_avatars)
    end

    def trigger_enable
      DiscourseEvent.trigger(:site_setting_changed, :enable_upload_debug_mode, false, true)
    end

    it "marks the plugin's upcoming changes as already notified about" do
      trigger_enable

      expect(
        UpcomingChangeEvent.where(upcoming_change_name: :show_user_menu_avatars).pluck(:event_type),
      ).to contain_exactly("added", "admins_notified_automatic_promotion")
    end

    it "leaves changes owned by core and other plugins alone" do
      trigger_enable

      expect(
        UpcomingChangeEvent.exists?(
          upcoming_change_name: :enable_experimental_admin_ui_grouped_filters,
        ),
      ).to eq(false)
    end

    it "does nothing when the plugin is disabled" do
      expect {
        DiscourseEvent.trigger(:site_setting_changed, :enable_upload_debug_mode, true, false)
      }.not_to change { UpcomingChangeEvent.count }
    end

    it "does nothing for a setting that is not a plugin's enabled setting" do
      expect {
        DiscourseEvent.trigger(:site_setting_changed, :show_user_menu_avatars, false, true)
      }.not_to change { UpcomingChangeEvent.count }
    end

    it "is a no-op when the plugin is re-enabled" do
      trigger_enable

      expect { trigger_enable }.not_to change { UpcomingChangeEvent.count }
    end
  end
end
