# coding: utf-8
# frozen_string_literal: true

require 'rails_helper'

describe EmojiHelper do

  describe "emoji_codes_to_img" do
    it "replaces emoji codes by images" do
      str = "This is a good day :woman: :man:t4:"
      replaced_str = helper.emoji_codes_to_img(str)

      expect(replaced_str).to eq("This is a good day <img src=\"/images/emoji/twitter/woman.png?v=#{Emoji::EMOJI_VERSION}\" title=\"woman\" class=\"emoji\" alt=\"woman\"> <img src=\"/images/emoji/twitter/man/4.png?v=#{Emoji::EMOJI_VERSION}\" title=\"man:t4\" class=\"emoji\" alt=\"man:t4\">")
    end

    it "doesn't replace if code doesn't exist" do
      str = "This is a good day :woman: :foo: :bar:t4: :man:t8:"
      replaced_str = helper.emoji_codes_to_img(str)

      expect(replaced_str).to eq("This is a good day <img src=\"/images/emoji/twitter/woman.png?v=#{Emoji::EMOJI_VERSION}\" title=\"woman\" class=\"emoji\" alt=\"woman\"> :foo: :bar:t4: :man:t8:")
    end
  end

end
