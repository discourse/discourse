# frozen_string_literal: true

require "vips"

RSpec.describe DiscourseVips do
  describe ".resize" do
    include ImageOrientationHelpers

    it "rotates a large image and preserves its color layout" do
      Dir.mktmpdir do |directory|
        source_path = File.join(directory, "source.jpg")
        left = Vips::Image.black(600, 1600).new_from_image([255, 0, 0])
        right = Vips::Image.black(600, 1600).new_from_image([0, 0, 255])
        left
          .join(right, :horizontal)
          .copy(interpretation: :srgb)
          .jpegsave(source_path, Q: 95, strip: true)

        with_jpeg_orientation(source_path:, orientation: 8) do |oriented_file|
          %w[jpeg png].each do |input_format|
            input_path = oriented_file.path
            if input_format == "png"
              input_path = File.join(directory, "oriented.png")
              Vips::Image.jpegload(oriented_file.path).pngsave(input_path)
            end
            output_path = File.join(directory, "#{input_format}-result.jpg")
            expect(Vips::Image.new_from_file(input_path).get("orientation")).to eq(8)

            described_class.resize(
              input_path:,
              output_path:,
              input_format:,
              output_format: "jpeg",
              width: 1600,
              height: 1200,
              quality: 95,
              strip_metadata: false,
              timeout: 5,
            )

            image = Vips::Image.jpegload(output_path)
            expect([image.width, image.height]).to eq([1600, 1200])
            expect(image.getpoint(800, 300)[2]).to be > 240
            expect(image.getpoint(800, 300)[0]).to be < 15
            expect(image.getpoint(800, 900)[0]).to be > 240
            expect(image.getpoint(800, 900)[2]).to be < 15
          end
        end
      end
    end
  end
end
