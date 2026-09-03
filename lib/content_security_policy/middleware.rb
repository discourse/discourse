# frozen_string_literal: true
require "content_security_policy"

class ContentSecurityPolicy
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)
      _, headers, _ = response = @app.call(env)

      return response if headers["Content-Security-Policy"].present?
      return response unless html_response?(headers)

      prevent_framing = headers["X-Frame-Options"] == "DENY"

      # The EnforceHostname middleware ensures request.host_with_port can be trusted
      protocol =
        (SiteSetting.force_https || request.ssl?) ? "https://" : "http://"
      base_url = protocol + request.host_with_port + Discourse.base_path

      theme_id = env[:resolved_theme_id]

      if SiteSetting.content_security_policy || prevent_framing
        enforced_policy =
          policy(theme_id, base_url: base_url, path_info: env["PATH_INFO"])
        headers["Content-Security-Policy"] = (
          if prevent_framing
            policy_preventing_framing(enforced_policy)
          else
            enforced_policy
          end
        )
      end
      headers["Content-Security-Policy-Report-Only"] = policy(
        theme_id,
        base_url: base_url,
        path_info: env["PATH_INFO"],
        report_only: true
      ) if SiteSetting.content_security_policy_report_only

      response
    end

    private

    delegate :policy, to: :ContentSecurityPolicy

    def policy_preventing_framing(policy)
      directives = policy.split(";").map(&:strip)
      directives.reject! do |directive|
        directive.start_with?("frame-ancestors ")
      end
      directives << "frame-ancestors 'none'"
      directives.join("; ")
    end

    def html_response?(headers)
      headers["Content-Type"] && headers["Content-Type"] =~ /html/
    end
  end
end
