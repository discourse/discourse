# frozen_string_literal: true
require_dependency 'content_security_policy'

class ContentSecurityPolicy
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)
      _, headers, _ = response = @app.call(env)

      return response unless html_response?(headers)
      ContentSecurityPolicy.base_url = request.host_with_port if !Rails.env.production?

      theme_ids = env[:resolved_theme_ids]

      headers['Content-Security-Policy'] = policy(theme_ids, path_info: env["PATH_INFO"]) if SiteSetting.content_security_policy
      headers['Content-Security-Policy-Report-Only'] = policy(theme_ids, path_info: env["PATH_INFO"]) if SiteSetting.content_security_policy_report_only

      response
    end

    private

    delegate :policy, to: :ContentSecurityPolicy

    def html_response?(headers)
      headers['Content-Type'] && headers['Content-Type'] =~ /html/
    end
  end
end
