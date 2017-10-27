if (Rails.env.production? && SiteSetting.logging_provider == 'lograge') || ENV["ENABLE_LOGRAGE"]
  Rails.application.configure do
    config.lograge.enabled = true

    config.lograge.custom_options = lambda do |event|
      exceptions = %w(controller action format id)
      { params: event.payload[:params].except(*exceptions) }
    end
  end
end
