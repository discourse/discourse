# frozen_string_literal: true

RSpec.describe SiteSettings::HiddenProvider do
  let(:hidden_provider) { SiteSettings::HiddenProvider.new }

  describe "all" do
    it "can return defaults" do
      hidden_provider.add_hidden(:secret_setting)
      hidden_provider.add_hidden(:internal_thing)
      expect(hidden_provider.all).to include(:secret_setting, :internal_thing)

      hidden_provider.remove_hidden(:secret_setting)
      expect(hidden_provider.all).to include(:internal_thing)
      expect(hidden_provider.all).not_to include(:secret_setting)
    end

    it "can return results from modifiers" do
      hidden_provider.add_hidden(:secret_setting)
      plugin = Plugin::Instance.new
      modifier = ->(defaults) { defaults + [:other_setting] }
      plugin.register_modifier(:hidden_site_settings, &modifier)

      expect(hidden_provider.all).to include(:secret_setting, :other_setting)
    ensure
      DiscoursePluginRegistry.unregister_modifier(plugin, :hidden_site_settings, &modifier)
    end

    context "with an upcoming change that declares hide_settings" do
      # A name no real setting uses, so a change shipping `hide_settings` in
      # `site_settings.yml` can never collide with these expectations.
      let(:legacy_setting) { :stand_in_legacy_setting }

      def mock_change_hiding_legacy_setting(status:)
        mock_upcoming_change_metadata(
          {
            enable_upload_debug_mode: {
              impact: "other,developers",
              status: status,
              impact_type: "other",
              impact_role: "developers",
              hide_settings: [legacy_setting],
            },
          },
        )
      end

      it "hides them once an admin opts in" do
        mock_change_hiding_legacy_setting(status: :experimental)

        expect(hidden_provider.all).not_to include(legacy_setting)

        SiteSetting.enable_upload_debug_mode = true

        expect(hidden_provider.all).to include(legacy_setting)
      end

      it "hides them when auto-promotion enables the change on its own" do
        mock_change_hiding_legacy_setting(status: :beta)

        SiteSetting.promote_upcoming_changes_on_status = :stable
        expect(hidden_provider.all).not_to include(legacy_setting)

        SiteSetting.promote_upcoming_changes_on_status = :beta

        expect(hidden_provider.all).to include(legacy_setting)
      end
    end
  end
end
