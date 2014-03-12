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
SiteSetting.enforce_global_nicknames          = true
SiteSetting.default_external_links_in_new_tab = true
