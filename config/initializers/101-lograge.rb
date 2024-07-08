# frozen_string_literal: true

Rails.application.config.to_prepare do
  if (Rails.env.production? && SiteSetting.logging_provider == "lograge") ||
       (ENV["ENABLE_LOGRAGE"] == "1")
    require "lograge"

    if Rails.configuration.multisite
      Rails.logger.formatter =
        ActiveSupport::Logger::SimpleFormatter.new.extend(ActiveSupport::TaggedLogging::Formatter)
    end

    Rails.application.configure do
      config.lograge.enabled = true

      # Monkey patch Rails::Rack::Logger#logger to silence its logs.
      # The `lograge` gem is supposed to do this but it broke after we upgraded to Rails 7.1.
      # This patch is a temporary workaround until we find a proper fix.
      Rails::Rack::Logger.prepend(Module.new { def logger = (@logger ||= Logger.new(IO::NULL)) })

      Lograge.ignore(
        lambda do |event|
          # this is our hijack magic status,
          # no point logging this cause we log again
          # direct from hijack
          event.payload[:status] == 418
        end,
      )

      config.lograge.custom_payload do |controller|
        begin
          username =
            begin
              controller.current_user&.username if controller.respond_to?(:current_user)
            rescue Discourse::InvalidAccess, Discourse::ReadOnly, ActiveRecord::ReadOnlyError
              nil
            end

          ip =
            begin
              controller.request.remote_ip
            rescue ActionDispatch::RemoteIp::IpSpoofAttackError
              nil
            end

          { ip: ip, username: username }
        rescue => e
          Rails.logger.warn(
            "Failed to append custom payload: #{e.message}\n#{e.backtrace.join("\n")}",
          )
          {}
        end
      end

      config.lograge.custom_options =
        lambda do |event|
          begin
            exceptions = %w[controller action format id]

            params = event.payload[:params].except(*exceptions)

            if (file = params[:file]) && file.respond_to?(:headers)
              params[:file] = file.headers
            end

            if (files = params[:files]) && files.respond_to?(:map)
              params[:files] = files.map { |f| f.respond_to?(:headers) ? f.headers : f }
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
            Rails.logger.warn(
              "Failed to append custom options: #{e.message}\n#{e.backtrace.join("\n")}",
            )
            {}
          end
        end

      if ENV["ENABLE_LOGSTASH_LOGGER"] == "1"
        config.lograge.formatter = Lograge::Formatters::Logstash.new

        require "discourse_logstash_logger"

        config.lograge.logger =
          DiscourseLogstashLogger.logger(
            logdev: Rails.root.join("log", "#{Rails.env}.log"),
            type: :rails,
            customize_event:
              lambda do |event|
                event["database"] = RailsMultisite::ConnectionManagement.current_db
              end,
          )

        # Stop broadcasting to Rails' default logger
        Rails.logger.stop_broadcasting_to(
          Rails.logger.broadcasts.find { |logger| logger.is_a?(ActiveSupport::Logger) },
        )

        Logster.logger.subscribe do |severity, message, progname, opts, &block|
          config.lograge.logger.add_with_opts(severity, message, progname, opts, &block)
        end
      end
    end
  end
end
