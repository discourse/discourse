# frozen_string_literal: true

# load up git version into memory
# this way if it changes underneath we still have
# the original version
Discourse.git_version

if GlobalSetting.skip_redis?
  # Requiring this file explicitly prevents it from being autoloaded and so the
  # provider attribute is not cleared
  require File.expand_path('../../../app/models/site_setting', __FILE__)

  require 'site_settings/local_process_provider'
  Rails.cache = Discourse.cache
  SiteSetting.provider = SiteSettings::LocalProcessProvider.new
  return
end

reload_settings = lambda {
  RailsMultisite::ConnectionManagement.safe_each_connection do
    begin
      SiteSetting.refresh!

      unless String === SiteSetting.push_api_secret_key && SiteSetting.push_api_secret_key.length == 32
        SiteSetting.push_api_secret_key = SecureRandom.hex
      end
    rescue ActiveRecord::StatementInvalid
      # This will happen when migrating a new database
    end
  end
}

reload_settings.call

if !Rails.configuration.cache_classes
  ActiveSupport::Reloader.to_prepare do
    reload_settings.call
  end
end
