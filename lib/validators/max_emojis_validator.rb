# frozen_string_literal: true

class MaxEmojisValidator < ActiveModel::EachValidator

  def validate_each(record, attribute, value)
    unescaped_title = PrettyText.unescape_emoji(Emoji.unicode_unescape(CGI::escapeHTML(value)))
    if unescaped_title.present? && unescaped_title.scan(/<img.+?class\s*=\s*'(emoji|emoji emoji-custom)'/).size > SiteSetting.max_emojis_in_title
      record.errors.add(
        attribute, SiteSetting.max_emojis_in_title > 0 ? :max_emojis : :emojis_disabled,
        max_emojis_count: SiteSetting.max_emojis_in_title
      )
    end
  end
end
