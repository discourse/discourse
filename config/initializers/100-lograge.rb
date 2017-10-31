if (Rails.env.production? && SiteSetting.logging_provider == 'lograge') || ENV["ENABLE_LOGRAGE"]
  require 'lograge'

  Rails.application.configure do
    config.lograge.enabled = true

    config.lograge.custom_options = lambda do |event|
      exceptions = %w(controller action format id)

      output = {
        params: event.payload[:params].except(*exceptions),
        database: RailsMultisite::ConnectionManagement.current_db,
        time: event.time,
      }
    end
  end
end
