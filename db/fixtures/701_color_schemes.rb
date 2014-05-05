ColorScheme.seed do |s|
  s.id = 1
  s.name = I18n.t("color_schemes.base_theme_name")
  s.enabled = false
end

ColorSchemeColor::BASE_COLORS.each_with_index do |color, i|
  ColorSchemeColor.seed do |c|
    c.id = i+1
    c.name = color[0]
    c.hex = color[1]
    c.color_scheme_id = 1
  end
end
