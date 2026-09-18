# frozen_string_literal: true

require "image_magick"

RSpec.describe ImageMagick do
  describe ".magick" do
    it "writes JPEG data with write access to only the output file" do
      input_path = file_from_fixtures("logo.png").path

      Tempfile.create(%w[output .jpg]) do |output|
        described_class.magick(
          input_path,
          output.path,
          operation: :upload_format_conversion,
          read: [input_path],
          write: [output.path],
        )

        expect(FastImage.type(output.path)).to eq(:jpeg)
      end
    end

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
