# frozen_string_literal: true

class TopMenuValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val.blank?
    val_choices = val.split("|").map(&:strip).compact

    return false if !val_choices.all? { |choice| TopMenu.choices.include?(choice) }

    return false if !val_choices.include?("latest")

    val_choices.each do |choice|
      return false if choice == "unread" && UpcomingChanges.enabled?(:enable_unified_new)
    end

    true
  end

  def error_message
    I18n.t("site_settings.errors.top_menu_unread_not_allowed_with_unified_new")
  end
end
