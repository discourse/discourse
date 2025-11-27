# frozen_string_literal: true

module Middleware
  class Sendfile
    def initialize(app, header = "X-Accel-Redirect")
      @app = app
      @header = header
    end

    def call(env)
      status, headers, body = @app.call(env)
      [status, headers, body]
    end
  end
end
