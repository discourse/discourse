# frozen_string_literal: true

class Middleware::ProcessingRequest
  PROCESSING_REQUEST_THREAD_KEY = "discourse.processing_request"
  REQUEST_QUEUE_SECONDS_ENV_KEY = "REQUEST_QUEUE_SECONDS"

  def initialize(app)
    @app = app
  end

  def call(env)
    Thread.current[PROCESSING_REQUEST_THREAD_KEY] = true
    populate_request_queue_seconds!(env)
    @app.call(env)
  ensure
    Thread.current[PROCESSING_REQUEST_THREAD_KEY] = nil
  end

  private

  def populate_request_queue_seconds!(env)
    if queue_start = env["HTTP_X_REQUEST_START"]
      queue_start =
        if queue_start.start_with?("t=")
          queue_start.split("t=")[1].to_f
        else
          queue_start.to_f / 1000.0
        end

      queue_time = (Time.now.to_f - queue_start)
      env[REQUEST_QUEUE_SECONDS_ENV_KEY] = queue_time
    end
  end
end
