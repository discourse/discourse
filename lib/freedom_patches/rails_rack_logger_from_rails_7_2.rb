# frozen_string_literal: true

# TODO: Drop this patch when upgrading to Rails 7.2
#
# Here we use the code from Rails 7.2 because the code from Rails 7.1 has a
# nasty bug that happens when there is more than one tagged logger in the
# broadcast logger.
# The Rails 7.1 implementation calls `#call_app` as many times as there are
# tagged loggers, which leads to all sort of strange behaviors.
module RailsRackLoggerFromRails7_2
  extend ActiveSupport::Concern

  def call(env)
    request = ActionDispatch::Request.new(env)

    env["rails.rack_logger_tag_count"] = if logger.respond_to?(:push_tags)
      logger.push_tags(*compute_tags(request)).size
    else
      0
    end

    call_app(request, env)
  end

  private

  def call_app(request, env) # :doc:
    logger_tag_pop_count = env["rails.rack_logger_tag_count"]

    instrumenter = ActiveSupport::Notifications.instrumenter
    handle = instrumenter.build_handle("request.action_dispatch", { request: request })
    handle.start

    logger.info { started_request_message(request) }
    status, headers, body = response = @app.call(env)
    body =
      ::Rack::BodyProxy.new(body) { finish_request_instrumentation(handle, logger_tag_pop_count) }

    if response.frozen?
      [status, headers, body]
    else
      response[2] = body
      response
    end
  rescue Exception
    finish_request_instrumentation(handle, logger_tag_pop_count)
    raise
  end

  def finish_request_instrumentation(handle, logger_tag_pop_count)
    handle.finish
    if logger.respond_to?(:pop_tags) && logger_tag_pop_count > 0
      logger.pop_tags(logger_tag_pop_count)
    end
    ActiveSupport::LogSubscriber.flush_all!
  end
end
Rails::Rack::Logger.prepend(RailsRackLoggerFromRails7_2)
