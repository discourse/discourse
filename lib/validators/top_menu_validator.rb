# frozen_string_literal: true

class TopMenuValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    @error_message = "site_settings.errors.invalid_string"

    if val.blank?
      @error_message = "site_settings.errors.must_include_latest"
      return false
    end

    val_choices = val.split("|").map(&:strip).compact

    if val_choices.include?("unread") && UpcomingChanges.enabled?(:enable_unified_new)
      @error_message = "site_settings.errors.top_menu_unread_not_allowed_with_unified_new"
      return false
    end

    return false if !val_choices.all? { |choice| TopMenu.choices.include?(choice) }

    if !val_choices.include?("latest")
      @error_message = "site_settings.errors.must_include_latest"
      return false
    end

    true
  end

  def error_message
    I18n.t(@error_message)
  end
end
