# Configure Discourse Settings with Lesson Planet Community Settings (rake db:seed_fu)
#

# Load the latest settings
SiteSetting.refresh!

#
# SSO
#
SiteSetting.enable_sso                        = true
SiteSetting.sso_url                           = ENV['SSO_URL']
SiteSetting.sso_secret                        = ENV['SSO_SECRET']
SiteSetting.sso_overrides_email               = true
SiteSetting.sso_overrides_username            = true
SiteSetting.sso_overrides_name                = true
SiteSetting.enable_names                      = true

#
# General
#
SiteSetting.enable_local_account_create       = false
SiteSetting.enforce_global_nicknames          = false
SiteSetting.default_external_links_in_new_tab = true


#
# LessonPlanet API
#
user = User.where(username_lower: ENV['API_USERNAME'].downcase).first
if user.blank?
  user = User.seed do |u|
    u.name = "Lesson Planet"
    u.username = ENV['API_USERNAME']
    u.username_lower = ENV['API_USERNAME'].downcase
    u.email = "member_services@lessonplanet.com"
    u.password = SecureRandom.hex
    # TODO localize this, its going to require a series of hacks
    u.bio_raw = "Not a real person. A global user for system notifications and other system tasks."
    u.active = true
    u.admin = true
    u.moderator = true
    u.email_direct = false
    u.approved = true
    u.email_private_messages = false
    u.trust_level = TrustLevel.levels[:elder]
  end.first
end

if user
  api_key = ApiKey.where(user_id: user.id).first_or_initialize
  api_key.update(key: ENV['API_KEY'], created_by: user)
end
