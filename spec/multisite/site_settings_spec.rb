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
end
