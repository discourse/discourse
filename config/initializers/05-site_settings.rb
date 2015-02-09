# load up git version into memory
# this way if it changes underneath we still have
# the original version
Discourse.git_version

reload_settings = lambda {
  RailsMultisite::ConnectionManagement.each_connection do
    begin
      SiteSetting.refresh!
    rescue ActiveRecord::StatementInvalid
      # This will happen when migrating a new database
    end
  end
}

if Rails.configuration.cache_classes
  reload_settings.call
else
  ActionDispatch::Reloader.to_prepare do
    reload_settings.call
  end
end
