# frozen_string_literal: true

RSpec.describe EmojiSetSiteSetting do
  describe ".valid_value?" do
    it "accepts noto_3d and rejects unknown emoji sets" do
      expect(EmojiSetSiteSetting.valid_value?("noto_3d")).to be(true)
      expect(EmojiSetSiteSetting.valid_value?("nonexistent_emoji_set")).to be(false)
    end
  end

  describe ".values" do
    it "maps every configured emoji set to an existing asset directory and client translation" do
      EmojiSetSiteSetting.values.each do |option|
        expect(File.directory?(File.join(DiscourseEmojis.path_for_emojis, option[:value]))).to be(
          true,
        )
        expect(I18n.exists?("js.#{option[:name]}", :en)).to be(true)
      end
    end

    it "resolves emoji URLs for noto_3d" do
      SiteSetting.emoji_set = "noto_3d"
      expect(Emoji.url_for("smile")).to eq(
        "/images/emoji/noto_3d/smile.png?v=#{Emoji::EMOJI_VERSION}",
      )
    end
  end
end
