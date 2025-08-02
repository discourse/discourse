# frozen_string_literal: true

describe "HashtagAutocompleteService multisite registry", type: :multisite do
  class MockPlugin
    def initialize(setting_provider)
      @setting_provider = setting_provider
    end

    def enabled?
      @setting_provider.find("bookmark_hashtag_enabled")&.value == "true"
    end
  end

  it "does not include the data source if one of the multisites has the plugin disabled" do
    setting_provider = SiteSettings::LocalProcessProvider.new
    DiscoursePluginRegistry.register_hashtag_autocomplete_data_source(
      FakeBookmarkHashtagDataSource,
      MockPlugin.new(setting_provider),
    )

    test_multisite_connection("default") do
      setting_provider.save("bookmark_hashtag_enabled", true, 5)
      expect(HashtagAutocompleteService.data_source_types).to eq(%w[category tag bookmark])
    end

    test_multisite_connection("second") do
      expect(HashtagAutocompleteService.data_source_types).to eq(%w[category tag])
    end
  end
end
