# frozen_string_literal: true

class ColorSchemeSetting < EnumSiteSetting
  def self.valid_value?(val)
    val == -1 || ColorScheme.find_by_id(val)
  end

  def self.values
    values = [{ name: I18n.t("site_settings.dark_mode_none"), value: -1 }]
    ColorScheme.all.map { |c| values << { name: c.name, value: c.id } }
    values
  end
end
