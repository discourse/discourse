# frozen_string_literal: true

module Middleware
  class FrameOptions
    def initialize(app, settings = {})
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      headers.except!('X-Frame-Options') if SiteSetting.allow_embedding_site_in_an_iframe
      [status, headers, body]
    end
  end
end
