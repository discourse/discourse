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

  describe ".identify" do
    it "denies vendor file reads unless explicitly allowed" do
      skip "requires Landlock" if !Landlock.supported?

      Dir.mktmpdir("imagemagick-sandbox-", Rails.root.join("vendor")) do |directory|
        input_path = File.join(directory, "input.png")
        FileUtils.cp(file_from_fixtures("logo.png").path, input_path)

        expect {
          described_class.identify(input_path, operation: :optimized_image_resize)
        }.to raise_error(Discourse::Utils::CommandError)

        expect(
          described_class.identify(
            input_path,
            operation: :optimized_image_resize,
            read: [input_path],
          ),
        ).to include("PNG")
      end
    end
  end
end
