# frozen_string_literal: true

module EmojiHelper
  def emoji_codes_to_img(str)
    return if str.blank?

    str = str.gsub(/:([\w\-+]*(?::t\d)?):/) do |name|
      code = $1

      if code && Emoji.custom?(code)
        emoji = Emoji[code]
        "<img src=\"#{emoji.url}\" title=\"#{code}\" class=\"emoji\" alt=\"#{code}\">"
      elsif code && Emoji.exists?(code)
        "<img src=\"#{Emoji.url_for(code)}\" title=\"#{code}\" class=\"emoji\" alt=\"#{code}\">"
      else
        name
      end
    end

    raw(str)
  end
end
