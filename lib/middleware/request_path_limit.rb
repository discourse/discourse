# frozen_string_literal: true

require "route_recognizer"

class Middleware::RequestPathLimit
  def initialize(app)
    @app = app
  end

  def call(env)
    unless RouteRecognizer.valid_path?(env["PATH_INFO"])
      body = env["REQUEST_METHOD"] == "HEAD" ? [] : ["Not Found"]
      return 404, { "Content-Type" => "text/plain; charset=utf-8" }, body
    end

    @app.call(env)
  end
end
