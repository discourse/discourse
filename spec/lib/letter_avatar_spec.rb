# frozen_string_literal: true

require "letter_avatar"

RSpec.describe LetterAvatar do
  describe ".cleanup_old" do
    it "removes stale cache directories" do
      cache_path = LetterAvatar.cache_path
      parent_path = File.dirname(cache_path)
      stale_path = File.join(parent_path, "stale")
      FileUtils.mkdir_p([cache_path, stale_path])

      described_class.cleanup_old

      expect(Dir.children(parent_path)).to contain_exactly(File.basename(cache_path))
    end
  end

  describe ".generate" do
    it "generates a PNG avatar with the requested dimensions and a white glyph" do
      username = "A"
      avatar_size = 45
      identity = LetterAvatar::Identity.from_username(username)
      generated_path = described_class.generate(username, avatar_size, cache: false)
      fullsize_path = described_class.fullsize_path(identity)

      expect(FastImage.type(generated_path)).to eq(:png)
      expect(FastImage.size(generated_path)).to eq([avatar_size, avatar_size])
      expect(
        ChunkyPNG::Image
          .from_file(fullsize_path)
          .pixels
          .any? do |pixel|
            ChunkyPNG::Color.r(pixel) == 255 && ChunkyPNG::Color.g(pixel) == 255 &&
              ChunkyPNG::Color.b(pixel) == 255
          end,
      ).to eq(true)
    ensure
      if generated_path
        FileUtils.rm_f(generated_path)
        FileUtils.rm_f(described_class.fullsize_path(identity))
      end
    end
  end
end
