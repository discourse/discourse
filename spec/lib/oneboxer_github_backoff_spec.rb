# frozen_string_literal: true

RSpec.describe Oneboxer do
  describe ".external_onebox_ttl" do
    it "uses a short TTL for a blank/failed result and 1 day for a successful one" do
      expect(Oneboxer.external_onebox_ttl({ onebox: "", preview: "" })).to eq(1.minute)
      expect(Oneboxer.external_onebox_ttl({ onebox: "<aside>onebox</aside>", preview: "x" })).to eq(
        1.day,
      )
    end
  end

  describe "InlineOneboxer caching" do
    it "uses a short TTL for a failed lookup (blank title)" do
      Discourse.cache.expects(:write).with(anything, anything, expires_in: 1.minute)
      InlineOneboxer.send(:onebox_for, "https://example.com/x", nil, {})
    end

    it "uses the normal 1 day TTL when a title is found" do
      Discourse.cache.expects(:write).with(anything, anything, expires_in: 1.day)
      InlineOneboxer.send(:onebox_for, "https://example.com/x", "Some title", {})
    end
  end
end
