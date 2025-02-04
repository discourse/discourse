# frozen_string_literal: true

if ENV["ENABLE_LOGSTASH_LOGGER"] == "1"
  require "lograge"

  Rails.application.config.after_initialize do
    def unsubscribe(component_name, subscriber)
      subscriber
        .public_methods(false)
        .reject { |method| method.to_s == "call" }
        .each do |event|
          ActiveSupport::Notifications
            .notifier
            .all_listeners_for("#{event}.#{component_name}")
            .each do |listener|
              if listener
                   .instance_variable_get("@delegate")
                   .class
                   .to_s
                   .start_with?("#{component_name.to_s.classify}::LogSubscriber")
                ActiveSupport::Notifications.unsubscribe listener
              end
            end
        end
    end

    # This is doing what the `lograge` gem is doing but has stopped working after we upgraded to Rails 7.1 and the `lograge`
    # gem does not seem to be maintained anymore so we're shipping our own fix. In the near term, we are considering
    # dropping the lograge gem and just port the relevant code to our codebase.
    #
    # Basically, this code silences log events coming from `ActionView::Logsubscriber` and `ActionController::LogSubscriber`
    # since those are just noise.
    ActiveSupport::LogSubscriber.log_subscribers.each do |subscriber|
      case subscriber
      when ActionView::LogSubscriber
        unsubscribe(:action_view, subscriber)
      when ActionController::LogSubscriber
        unsubscribe(:action_controller, subscriber)
      end
    end
  end

  Rails.application.config.to_prepare do
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
              if sql = data[:sql]
                output[:db] = sql[:duration] * 1000
                output[:db_calls] = sql[:calls]
              end

              if redis = data[:redis]
                output[:redis] = redis[:duration] * 1000
                output[:redis_calls] = redis[:calls]
              end

              if net = data[:net]
                output[:net] = net[:duration] * 1000
                output[:net_calls] = net[:calls]
              end

              # MethodProfiler.stop is called after this lambda, so the delta
              # must be computed here.
              if data[:__start_gc_heap_live_slots]
                output[:heap_live_slots] = GC.stat[:heap_live_slots] -
                  data[:__start_gc_heap_live_slots]
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

      config.lograge.formatter = Lograge::Formatters::Logstash.new

      require "discourse_logstash_logger"

      config.lograge.logger =
        DiscourseLogstashLogger.logger(
          logdev: Rails.root.join("log", "#{Rails.env}.log"),
          type: :rails,
          customize_event:
            lambda { |event| event["database"] = RailsMultisite::ConnectionManagement.current_db },
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
