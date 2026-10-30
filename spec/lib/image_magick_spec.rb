# frozen_string_literal: true

require "image_magick"

RSpec.describe ImageMagick do
  describe ".magick" do
    it "emits one measurement for a real command" do
      SiteSetting.instrument_image_processing = true

      events =
        DiscourseEvent.track_events(:image_processing_finished) do
          described_class.magick("--version", operation: :letter_avatar_version)
        end

      expect(events.size).to eq(1)
      payload = events.first[:params].first
      expect(payload.except(:duration_seconds)).to eq(
        operation: "letter_avatar_version",
        success: true,
      )
      expect(payload[:duration_seconds]).to be >= 0
    end
  end
end
