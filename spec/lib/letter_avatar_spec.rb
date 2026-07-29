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
    it "generates a bounded PNG avatar" do
      username = "image-processing-regression"
      path = LetterAvatar.generate(username, 45, cache: false)

      expect(FastImage.type(path)).to eq(:png)
      expect(FastImage.size(path)).to eq([45, 45])
      expect(File.size(path)).to be_between(100, 5000)
    ensure
      if path
        identity = LetterAvatar::Identity.from_username(username)
        FileUtils.rm_f(path)
        FileUtils.rm_f(LetterAvatar.fullsize_path(identity))
      end
    end

    it "generates a PNG avatar for a non-ASCII username" do
      username = "éclair"
      path = LetterAvatar.generate(username, 60, cache: false)

      expect(FastImage.type(path)).to eq(:png)
      expect(FastImage.size(path)).to eq([60, 60])
      expect(File.size(path)).to be > 100
    ensure
      if path
        identity = LetterAvatar::Identity.from_username(username)
        FileUtils.rm_f(path)
        FileUtils.rm_f(LetterAvatar.fullsize_path(identity))
      end
    end
  end
end
