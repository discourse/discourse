class MaxEmojisValidator < ActiveModel::EachValidator

  def validate_each(record, attribute, value)
    if Emoji.unicode_unescape(value).scan(/:([\w\-+]+(?::t\d)?):/).size > SiteSetting.max_emojis_in_title
      record.errors.add(
        attribute, :max_emojis,
        max_emojis_count: SiteSetting.max_emojis_in_title
      )
    end
  end
end
