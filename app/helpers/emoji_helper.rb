# frozen_string_literal: true

module EmojiHelper
  def emoji_codes_to_img(str)
    if str
      str = str.gsub(/:([\w\-+]*(?::t\d)?):/) do |name|
        code = $1
        "<img src=\"#{Emoji.url_for(code)}\" title=\"#{code}\" class=\"emoji\" alt=\"#{code}\">"
      end
      raw str
    end
  end
end
