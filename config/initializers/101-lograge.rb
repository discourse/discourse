if (Rails.env.production? && SiteSetting.logging_provider == 'lograge') || ENV["ENABLE_LOGRAGE"]
  require 'lograge'

  if Rails.configuration.multisite
    Rails.logger.formatter = ActiveSupport::Logger::SimpleFormatter.new
  end

  Rails.application.configure do
    config.lograge.enabled = true

    Lograge.ignore(lambda do |event|
      # this is our hijack magic status,
      # no point logging this cause we log again
      # direct from hijack
      event.payload[:status] == 418
    end)

    config.lograge.custom_payload do |controller|
      begin
        username =
          begin
            if controller.respond_to?(:current_user)
              controller.current_user&.username
            end
          rescue Discourse::InvalidAccess, Discourse::ReadOnly
            nil
          end

        ip =
          begin
            controller.request.remote_ip
          rescue ActionDispatch::RemoteIp::IpSpoofAttackError
            nil
          end

        {
          ip: ip,
          username: username
        }
      rescue => e
        Rails.logger.warn("Failed to append custom payload: #{e.message}\n#{e.backtrace.join("\n")}")
        {}
      end
    end

    config.lograge.custom_options = lambda do |event|
      begin
        exceptions = %w(controller action format id)

        params = event.payload[:params].except(*exceptions)

        if (file = params[:file]) && file.respond_to?(:headers)
          params[:file] = file.headers
        end

        if (files = params[:files]) && files.respond_to?(:map)
          params[:files] = files.map do |f|
            f.respond_to?(:headers) ? f.headers : f
          end
        end

        output = {
          params: params.to_query,
          database: RailsMultisite::ConnectionManagement.current_db,
        }

        if data = (Thread.current[:_method_profiler] || event.payload[:timings])
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

          net = data[:net]

          if net
            output[:net] = net[:duration] * 1000
            output[:net_calls] = net[:calls]
          end
        end

        output
      rescue RateLimiter::LimitExceeded
        # no idea who this is, but they are limited
        {}
      rescue => e
        Rails.logger.warn("Failed to append custom options: #{e.message}\n#{e.backtrace.join("\n")}")
        {}
      end
    end

    if ENV["LOGSTASH_URI"]
      config.lograge.formatter = Lograge::Formatters::Logstash.new

      require 'discourse_logstash_logger'

      config.lograge.logger = DiscourseLogstashLogger.logger(
        uri: ENV['LOGSTASH_URI'], type: :rails
      )

      # Remove ActiveSupport::Logger from the chain and replace with Lograge's
      # logger
      Rails.logger.chained.pop
      Rails.logger.chain(config.lograge.logger)
    end
  end
end
