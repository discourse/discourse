module Middleware

  class ApplyCDN

    def initialize(app, settings={})
      @app = app
    end

    def call(env)
      status, headers, response = @app.call(env)

      if Discourse.asset_host.present? &&
         Discourse.store.external? &&
        (headers["Content-Type"].start_with?("text/") ||
         headers["Content-Type"].start_with?("application/json"))
        response.body = response.body.gsub(Discourse.store.absolute_base_url, Discourse.asset_host)
      end

      [status, headers, response]
    end

  end

end
