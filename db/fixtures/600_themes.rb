# we can not guess what to do if customization already started, so skip it
if !Theme.exists?
  STDERR.puts "> Seeding dark and light themes"

  name = I18n.t("color_schemes.dark_theme_name")
  dark_scheme = ColorScheme.find_by(base_scheme_id: "Dark")
  dark_scheme ||= ColorScheme.create_from_base(name: name, via_wizard: true, base_scheme_id: "Dark")

  name = I18n.t('color_schemes.dark_theme_name')
  _dark_theme = Theme.create(name: name, user_id: -1,
                             color_scheme_id: dark_scheme.id,
                             user_selectable: true)

  name = I18n.t('color_schemes.default_theme_name')
  default_theme = Theme.create(name: name, user_id: -1,
                               user_selectable: true)

  default_theme.set_default!
end
