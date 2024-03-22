# frozen_string_literal: true

RSpec.describe Stat do
  describe "#api_stats" do
    it "skips discover stats when disabled" do
      Stat.api_stats.keys.exclude?("discourse_discover_enrolled")
    end

    it "includes discover stats when enrolled" do
      SiteSetting.include_in_discourse_discover = true
      discover_keys = %i[
        discourse_discover_enrolled
        discourse_discover_logo_url
        discourse_discover_locale
      ]
      expect(Stat.api_stats.keys).to include(*discover_keys)
    end
  end
end
