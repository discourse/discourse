# frozen_string_literal: true

require "chunky_png"
require "letter_avatar"

RSpec.describe LetterAvatar do
  def letter_avatar_identity(letter)
    identity = LetterAvatar::Identity.from_username("letter-avatar-pixel-regression")
    identity.letter = letter
    identity
  end

  def remove_generated_letter_avatars(generated_paths)
    generated_paths&.each do |letter, generated_path|
      FileUtils.rm_f(generated_path)
      FileUtils.rm_f(described_class.fullsize_path(letter_avatar_identity(letter)))
    end
  end

  describe ".cleanup_old" do
    it "removes stale cache directories" do
      path = LetterAvatar.cache_path

      FileUtils.mkdir_p(path + "junk")
      LetterAvatar.generate("test", 100)

      LetterAvatar.cleanup_old

      expect(Dir.entries(File.dirname(path)).length).to eq(3)
    end
  end

  describe ".generate" do
    it "generates distinct A-Z PNG avatars" do
      letters = ("A".."Z").to_a
      avatar_size = 45
      generated_paths = {}
      letters.each do |letter|
        generated_paths[letter] = described_class.generate(
          letter,
          avatar_size,
          identity: letter_avatar_identity(letter),
          cache: false,
        )
      end
      generated_images =
        generated_paths.transform_values { |path| ChunkyPNG::Image.from_file(path) }
      duplicate_letter_groups =
        generated_images
          .group_by { |_letter, image| image.pixels }
          .values
          .filter_map { |entries| entries.map(&:first) if entries.length > 1 }

      aggregate_failures "A-Z letter avatars" do
        generated_paths.each do |letter, path|
          image = generated_images.fetch(letter)

          expect(FastImage.type(path)).to eq(:png), "#{letter}: generated file was not a PNG"
          expect(image.width).to eq(avatar_size),
          "#{letter}: actual width #{image.width} did not match #{avatar_size}"
          expect(image.height).to eq(avatar_size),
          "#{letter}: actual height #{image.height} did not match #{avatar_size}"
        end

        expect(duplicate_letter_groups).to be_empty,
        "Expected distinct A-Z renderings, but these letters had identical pixels: " \
          "#{duplicate_letter_groups.map { |group| group.join("/") }.join(", ")}"
      end
    ensure
      remove_generated_letter_avatars(generated_paths)
    end
  end
end
