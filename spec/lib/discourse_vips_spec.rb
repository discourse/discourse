# frozen_string_literal: true

RSpec.describe DiscourseVips do
  describe ".version" do
    it "returns a cache version" do
      expect(described_class.version).to match(/\A\d+\.\d+\.\d+-8\.\d+\.\d+\z/)
    end

    it "emits an image-processing measurement" do
      SiteSetting.instrument_image_processing = true

      events = DiscourseEvent.track_events(:image_processing_finished) { described_class.version }

      expect(events.size).to eq(1)
      payload = events.first[:params].first
      expect(payload.except(:duration_seconds)).to eq(operation: "vips_version", success: true)
      expect(payload[:duration_seconds]).to be >= 0
    end
  end
end
