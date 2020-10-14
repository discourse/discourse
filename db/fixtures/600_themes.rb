# frozen_string_literal: true

# we can not guess what to do if customization already started, so skip it
if !Theme.exists?
  STDERR.puts "> Seeding theme and color schemes"

  name = I18n.t("color_schemes.dark_theme_name")
  dark_scheme = ColorScheme.find_by(base_scheme_id: "Dark")
  dark_scheme ||= ColorScheme.create_from_base(name: name, via_wizard: true, base_scheme_id: "Dark", user_selectable: true)

  name = I18n.t('color_schemes.default_theme_name')
  default_theme = Theme.create!(name: name, user_id: -1)
  default_theme.set_default!
end
