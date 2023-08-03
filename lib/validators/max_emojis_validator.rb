# frozen_string_literal: true

class MaxEmojisValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    if value.present? && PrettyText.count_emoji(value) > SiteSetting.max_emojis_in_title
      record.errors.add(
        attribute,
        SiteSetting.max_emojis_in_title > 0 ? :max_emojis : :emojis_disabled,
        max_emojis_count: SiteSetting.max_emojis_in_title,
      )
    end
  end
end
