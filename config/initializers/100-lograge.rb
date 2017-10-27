if (Rails.env.production? && SiteSetting.logging_provider == 'lograge') || ENV["ENABLE_LOGRAGE"]
  require 'lograge'

  Rails.application.configure do
    config.lograge.enabled = true

    config.lograge.custom_options = lambda do |event|
      exceptions = %w(controller action format id)

      {
        params: event.payload[:params].except(*exceptions),
        type: :rails
      }
    end

    if (logstash_uri = ENV["LOGSTASH_URI"].present?)
      require 'logstash-logger'

      config.lograge.formatter = Lograge::Formatters::Logstash.new

      config.lograge.logger = LogStashLogger.new(
        type: :tcp,
        uri: logstash_uri
      )
    end
  end
end
