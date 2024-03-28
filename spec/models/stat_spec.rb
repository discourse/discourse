# frozen_string_literal: true

RSpec.describe Stat do
  describe "#discourse_hub_stats" do
    it "skips discover stats when disabled" do
      Stat.discourse_hub_stats.keys.exclude?("discourse_discover_enrolled")
    end

    it "includes discover stats when enrolled" do
      SiteSetting.include_in_discourse_discover = true
      discover_keys = %i[
        discourse_discover_enrolled
        discourse_discover_logo_url
        discourse_discover_locale
      ]
      expect(Stat.discourse_hub_stats.keys).to include(*discover_keys)
    end
  end
end
