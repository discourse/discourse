# frozen_string_literal: true

# load up git version into memory
# this way if it changes underneath we still have
# the original version
Discourse.git_version

if GlobalSetting.skip_redis?
  require "site_settings/local_process_provider"
  Rails.cache = Discourse.cache
  Rails.application.config.to_prepare do
    SiteSetting.provider = SiteSettings::LocalProcessProvider.new
  end
  return
end

Rails.application.config.to_prepare do
  RailsMultisite::ConnectionManagement.safe_each_connection do
    begin
      SiteSetting.refresh!

      unless String === SiteSetting.push_api_secret_key &&
               SiteSetting.push_api_secret_key.length == 32
        SiteSetting.push_api_secret_key = SecureRandom.hex
      end
    rescue ActiveRecord::StatementInvalid
      # This will happen when migrating a new database
    end
  end
end
