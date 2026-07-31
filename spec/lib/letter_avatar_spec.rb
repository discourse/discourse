# frozen_string_literal: true

require "letter_avatar"

RSpec.describe LetterAvatar do
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
    it "generates a PNG avatar with the requested dimensions" do
      username = "A"
      avatar_size = 45
      generated_path = described_class.generate(username, avatar_size, cache: false)

      expect(FastImage.type(generated_path)).to eq(:png)
      expect(FastImage.size(generated_path)).to eq([avatar_size, avatar_size])
    ensure
      if generated_path
        identity = LetterAvatar::Identity.from_username(username)
        FileUtils.rm_f(generated_path)
        FileUtils.rm_f(described_class.fullsize_path(identity))
      end
    end
  end
end
