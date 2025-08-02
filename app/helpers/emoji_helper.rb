# frozen_string_literal: true

module EmojiHelper
  def emoji_codes_to_img(str)
    raw(Emoji.codes_to_img(str))
  end
end
