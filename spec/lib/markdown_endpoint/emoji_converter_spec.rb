# frozen_string_literal: true

require "rails_helper"

RSpec.describe MarkdownEndpoint::EmojiConverter do
  describe ".convert" do
    before { Plugin::CustomEmoji.clear_cache }
    after { Plugin::CustomEmoji.clear_cache }

    it "preserves custom emoji that share standard names or aliases" do
      Plugin::CustomEmoji.register("+1", "/custom/thumb.png")
      Plugin::CustomEmoji.register("wave", "/custom/wave.png")

      expect(described_class.convert(":+1: :wave: :wave:t4: :smile:")).to eq(
        ":+1: :wave: :wave:t4: 😄",
      )
    end

    it "preserves shortcodes when Unicode lookup returns a blank value" do
      SiteSetting.emoji_deny_list = "peach"
      Emoji.clear_cache

      expect(described_class.convert(":peach: :unknown_emoji: :smile:")).to eq(
        ":peach: :unknown_emoji: 😄",
      )
    end

    it "converts standard emoji and toned aliases" do
      expect(described_class.convert(":smile: :+1: :wave:t4: :thumbsup:t6:")).to eq("😄 👍 👋🏽 👍🏿")
    end
  end
end
