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
    rescue => e
      STDERR.puts "URGENT: #{e} Failed to initialize site #{RailsMultisite::ConnectionManagement.current_db}"
      # the show must go on, don't stop startup if multisite fails
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
