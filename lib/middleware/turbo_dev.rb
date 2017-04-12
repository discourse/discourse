# frozen_string_literal: true
module Middleware

  # Cheat and bypass Rails in development mode if the client attempts to download a static asset
  # that's already been downloaded.
  #
  # Also ensures that assets are not cached in development mode. Around Chrome 29, the behavior
  # of `must-revalidate` changed and would often not request assets that had changed.
  #
  #  To use, include in your project and add the following to development.rb:
  #
  #  require 'middleware/turbo_dev'
  #  config.middleware.insert 0, Middleware::TurboDev
  #
  class TurboDev
    def initialize(app, settings={})
      @app = app
    end

    def call(env)
      root = "#{GlobalSetting.relative_url_root}/assets/"
      is_asset = env['REQUEST_PATH'] && env['REQUEST_PATH'].starts_with?(root)

      # hack to bypass all middleware if serving assets, a lot faster 4.5 seconds -> 1.5 seconds
      if (etag = env['HTTP_IF_NONE_MATCH']) && is_asset
        name = env['REQUEST_PATH'][(root.length)..-1]
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
