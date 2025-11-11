# frozen_string_literal: true

class CssColorWithBlankValidator < CssColorValidator
  def valid_value?(val)
    return true if val.blank?
    !!(val =~ /\A#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})\z/ || COLORS.include?(val&.downcase))
  end

  def error_message
    I18n.t("site_settings.errors.invalid_css_color")
  end
end
