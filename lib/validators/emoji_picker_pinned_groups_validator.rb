# frozen_string_literal: true

class EmojiPickerPinnedGroupsValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val.blank?

    groups = val.split("|").map(&:strip).reject(&:blank?)
    valid_groups = Set.new(Emoji.allowed.map(&:group))

    invalid = groups.reject { |g| valid_groups.include?(g) }
    if invalid.any?
      @invalid_groups = invalid
      return false
    end

    true
  end

  def error_message
    I18n.t(
      "site_settings.errors.emoji_picker_pinned_groups_invalid",
      groups: @invalid_groups.join(", "),
      count: @invalid_groups.size,
    )
  end
end
