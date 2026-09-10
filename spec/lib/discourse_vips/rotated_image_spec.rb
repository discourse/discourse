# frozen_string_literal: true

require "vips"

RSpec.describe DiscourseVips do
  describe ".auto_orient" do
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
          input_path = oriented_file.path
          output_path = File.join(directory, "result.jpg")
          expect(Vips::Image.new_from_file(input_path).get("orientation")).to eq(8)

          described_class.auto_orient(input_path:, output_path:, source_quality: 95, timeout: 5)

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
