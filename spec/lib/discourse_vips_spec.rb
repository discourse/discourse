# frozen_string_literal: true

RSpec.describe DiscourseVips do
  describe ".vips" do
    it "emits an image-processing measurement" do
      SiteSetting.instrument_image_processing = true

      events =
        DiscourseEvent.track_events(:image_processing_finished) do
          described_class.vips("version", operation: :vips_version)
        end

      expect(events.size).to eq(1)
      payload = events.first[:params].first
      expect(payload.except(:duration_seconds)).to eq(operation: "vips_version", success: true)
      expect(payload[:duration_seconds]).to be >= 0
    end
  end
end
