module Middleware
  # this class cheats and bypasses rails altogether if the client attempts
  # to download a static asset
  class TurboDev
    def initialize(app, settings={})
      @app = app
    end
    def call(env)

      is_asset = (env['REQUEST_PATH'] =~ /^\/assets\//)

      # hack to bypass all middleware if serving assets, a lot faster 4.5 seconds -> 1.5 seconds
      if (etag = env['HTTP_IF_NONE_MATCH']) && is_asset
        name = $'
        etag = etag.gsub "\"", ""
        asset = Rails.application.assets.find_asset(name)
        if asset && asset.digest == etag
          return [304,{},[]]
        end
      end

      status, headers, response = @app.call(env)
      headers['Cache-Control'] = 'no-cache' if is_asset
      [status, headers, response]
    end
  end
end
