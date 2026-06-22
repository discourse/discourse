# frozen_string_literal: true

RSpec.describe SiteSettings::HiddenProvider do
  let(:provider_local) { SiteSettings::LocalProcessProvider.new }
  let(:settings) { new_settings(provider_local) }
  let(:hidden_provider) { SiteSettings::HiddenProvider.new }

  describe "all" do
    after { DiscoursePluginRegistry.clear_modifiers! }

    it "can return defaults" do
      hidden_provider.add_hidden(:secret_setting)
      hidden_provider.add_hidden(:internal_thing)
      expect(hidden_provider.all).to contain_exactly(:secret_setting, :internal_thing)

      hidden_provider.remove_hidden(:secret_setting)
      expect(hidden_provider.all).to contain_exactly(:internal_thing)
    end

    it "can return results from modifiers" do
      hidden_provider.add_hidden(:secret_setting)
      plugin = Plugin::Instance.new
      plugin.register_modifier(:hidden_site_settings) { |defaults| defaults + [:other_setting] }
      expect(hidden_provider.all).to contain_exactly(:secret_setting, :other_setting)
    end

    it "includes settings hidden by an enabled upcoming change that declares hide_settings" do
      mock_upcoming_change_metadata(
        {
          enable_upload_debug_mode: {
            impact: "other,developers",
            status: :experimental,
            impact_type: "other",
            impact_role: "developers",
            hide_settings: %i[allow_uncategorized_topics],
          },
        },
      )
      hidden_provider.add_hidden(:secret_setting)

      expect(hidden_provider.all).to contain_exactly(:secret_setting)

      SiteSetting.enable_upload_debug_mode = true

      expect(hidden_provider.all).to contain_exactly(:secret_setting, :allow_uncategorized_topics)
    ensure
      SiteSetting.remove_override!(:enable_upload_debug_mode)
      UpcomingChanges.clear_caches!
    end
  end
end
