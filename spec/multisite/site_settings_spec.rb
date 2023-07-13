# frozen_string_literal: true

RSpec.describe "Multisite SiteSettings", type: :multisite do
  before do
    @original_provider = SiteSetting.provider
    SiteSetting.provider = SiteSettings::DbProvider.new(SiteSetting)
  end

  after { SiteSetting.provider = @original_provider }

  describe "#default_locale" do
    it "should return the right locale" do
      test_multisite_connection("default") { expect(SiteSetting.default_locale).to eq("en") }

      test_multisite_connection("second") do
        SiteSetting.default_locale = "zh_TW"

        expect(SiteSetting.default_locale).to eq("zh_TW")
      end

      test_multisite_connection("default") do
        expect(SiteSetting.default_locale).to eq("en")

        SiteSetting.default_locale = "ja"

        expect(SiteSetting.default_locale).to eq("ja")
      end

      test_multisite_connection("second") { expect(SiteSetting.default_locale).to eq("zh_TW") }
    end
  end

  describe "transforming defaults from plugin" do
    class TestFilterPlugInstance < Plugin::Instance
    end

    let(:plugin_instance) { TestFilterPlugInstance.new }

    it "can change defaults" do
      test_multisite_connection("default") { expect(SiteSetting.title).to eq("Discourse") }

      plugin_instance.register_modifier(:site_setting_defaults) do |defaults|
        defaults.merge({ title: "title for #{RailsMultisite::ConnectionManagement.current_db}" })
      end

      test_multisite_connection("default") do
        SiteSetting.refresh!
        expect(SiteSetting.title).to eq("title for default")
        SiteSetting.title = "overridden default title"
        expect(SiteSetting.title).to eq("overridden default title")
      end

      test_multisite_connection("second") do
        SiteSetting.refresh!
        expect(SiteSetting.title).to eq("title for second")
        SiteSetting.title = "overridden second title"
        expect(SiteSetting.title).to eq("overridden second title")
      end
    ensure
      DiscoursePluginRegistry.reset!
      test_multisite_connection("default") { SiteSetting.refresh! }
      test_multisite_connection("second") { SiteSetting.refresh! }
    end
  end
end
