# frozen_string_literal: true

module EmojiHelper
  def emoji_codes_to_img(str)
    if str
      str = str.gsub(/:([\w\-+]*(?::t\d)?):/) do |name|
        code = $1
        if Emoji.exists?(code)
          "<img src=\"#{Emoji.url_for(code)}\" title=\"#{code}\" class=\"emoji\" alt=\"#{code}\">"
        else
          name
        end
      end
      raw str
    end
  end
end
