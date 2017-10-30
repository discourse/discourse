if (Rails.env.production? && SiteSetting.logging_provider == 'lograge') || ENV["ENABLE_LOGRAGE"]
  require 'lograge'

  Rails.application.configure do
    config.lograge.enabled = true

    logstash_uri = ENV["LOGSTASH_URI"]

    config.lograge.custom_options = lambda do |event|
      exceptions = %w(controller action format id)

      output = {
        params: event.payload[:params].except(*exceptions),
        database: RailsMultisite::ConnectionManagement.current_db,
        time: event.time,
      }

      output[:type] = :rails if logstash_uri
      output
    end

    if logstash_uri
      require 'logstash-logger'

      config.lograge.formatter = Lograge::Formatters::Logstash.new

      config.lograge.logger = LogStashLogger.new(
        type: :multi_delegator,
        outputs: [
          { uri: logstash_uri },
          { type: :file, path: "#{Rails.root}/log/#{Rails.env}.log", sync: true }
        ]
      )
    end
  end
end
