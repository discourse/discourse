# load up git version into memory
# this way if it changes underneath we still have
# the original version
Discourse.git_version

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
