module Middleware
  # this class cheats and bypasses rails altogether if the client attempts
  # to download a static asset
  class SsoCookieSessionkiller
    def initialize(app)
      @app = app
    end

    def call(env)
      req = Rack::Request.new(env)
      if req.cookies['sso_auth'].nil? && !req.cookies['_t'].nil?
        req.cookies.delete('_forum_session')
        req.cookies.delete('_t')
      end

      @app.call(env)
    end
  end
end
