# frozen_string_literal: true

require "image_magick"

RSpec.describe ImageMagick do
  describe ".image_quality" do
    it "reports source JPEG quality and the existing probe measurement" do
      SiteSetting.instrument_image_processing = true
      quality = nil

      events =
        DiscourseEvent.track_events(:image_processing_finished) do
          quality =
            described_class.image_quality(
              input_path: Rails.root.join("spec/fixtures/images/exif_orientation.jpg").to_s,
              timeout: 5,
            )
        end

      expect(quality).to eq(95)
      expect(events.first[:params].first).to include(
        operation: "upload_quality_probe",
        success: true,
      )
    end

    it "raises for an unreadable input" do
      expect do
        described_class.image_quality(input_path: "/nonexistent-image.jpg", timeout: 5)
      end.to raise_error(ArgumentError)
    end
  end

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
