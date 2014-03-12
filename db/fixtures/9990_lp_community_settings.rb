# Load the latest settings
SiteSetting.refresh!

# Configure Discourse Settings with Lesson Planet Community Settings (rake db:seed_fu)
SiteSetting.enable_sso             = true
SiteSetting.sso_url                = ENV['SSO_URL']
SiteSetting.sso_secret             = ENV['SSO_SECRET']
SiteSetting.sso_overrides_email    = true
SiteSetting.sso_overrides_username = true
SiteSetting.sso_overrides_name     = true
