if (Rails.env.production? && SiteSetting.logging_provider == 'lograge') || ENV["ENABLE_LOGRAGE"]
  require 'lograge'

  if Rails.configuration.multisite
    Rails.logger.formatter = ActiveSupport::Logger::SimpleFormatter.new
  end

  Rails.application.configure do
    config.lograge.enabled = true

    config.lograge.custom_payload do |controller|
      username = controller.try(:current_user)&.username rescue nil
      {
        ip: controller.request.remote_ip,
        username: username,
      }
    end

    config.lograge.custom_options = lambda do |event|
      exceptions = %w(controller action format id)

      params = event.payload[:params].except(*exceptions)
      params[:files].map!(&:headers) if params[:files]

      output = {
        params: params.to_query,
        database: RailsMultisite::ConnectionManagement.current_db,
      }

      if data = Thread.current[:_method_profiler]
        sql = data[:sql]

        if sql
          output[:db] = sql[:duration] * 1000
          output[:db_calls] = sql[:calls]
        end

        redis = data[:redis]

        if redis
          output[:redis] = redis[:duration] * 1000
          output[:redis_calls] = redis[:calls]
        end
      end

      output
    end

    if ENV["LOGSTASH_URI"]
      config.lograge.formatter = Lograge::Formatters::Logstash.new

      require 'discourse_logstash_logger'

      config.lograge.logger = DiscourseLogstashLogger.logger(
        uri: ENV['LOGSTASH_URI'], type: :rails
      )
    end
  end
end
