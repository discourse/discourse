# kind of odd, but we need it, we also need to nuke usage of User from inside migrations
#  very poor form
user = User.find_by("id <> -1 and username_lower = 'system'")
if user
  user.username = UserNameSuggester.suggest("system")
  user.save
end

I18n.locale = SiteSetting.default_locale || 'en'

User.seed do |u|
  u.id = -1
  u.name = I18n.t('site_settings.system_user_name', default: I18n.t('site_settings.system_user_name', locale: :en))
  u.username = 'system'
  u.username_lower = 'system'
  u.email = 'no_email'
  u.password = SecureRandom.hex
  u.bio_raw = I18n.t('site_settings.system_user_bio', default: I18n.t('site_settings.system_user_bio', locale: :en))
  u.active = true
  u.admin = true
  u.moderator = true
  u.email_direct = false
  u.approved = true
  u.email_private_messages = false
  u.trust_level = TrustLevel.levels[:elder]
end
