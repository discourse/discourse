# frozen_string_literal: true

class Middleware::ProcessingRequest
  PROCESSING_REQUEST_THREAD_KEY = "discourse.processing_request"

  def initialize(app)
    @app = app
  end

  def call(env)
    Thread.current[PROCESSING_REQUEST_THREAD_KEY] = true
    @app.call(env)
  ensure
    Thread.current[PROCESSING_REQUEST_THREAD_KEY] = nil
  end
end
