# frozen_string_literal: true
require_dependency 'global_path'

class ContentSecurityPolicy
  include GlobalPath

  class Middleware
    WHITELISTED_PATHS = %w(
      /logs
    )

    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)
      _, headers, _ = response = @app.call(env)

      return response unless html_response?(headers) && ContentSecurityPolicy.enabled?
      return response if whitelisted?(request.path)

      policy = ContentSecurityPolicy.new.build
      headers['Content-Security-Policy'] = policy if SiteSetting.content_security_policy
      headers['Content-Security-Policy-Report-Only'] = policy if SiteSetting.content_security_policy_report_only

      response
    end

    private

    def html_response?(headers)
      headers['Content-Type'] && headers['Content-Type'] =~ /html/
    end

    def whitelisted?(path)
      if GlobalSetting.relative_url_root
        path.slice!(/^#{Regexp.quote(GlobalSetting.relative_url_root)}/)
      end

      WHITELISTED_PATHS.any? { |whitelisted| path.start_with?(whitelisted) }
    end
  end

  def self.enabled?
    SiteSetting.content_security_policy || SiteSetting.content_security_policy_report_only
  end

  def initialize
    @directives = {
      script_src: script_src,
    }

    @directives[:report_uri] = path('/csp_reports') if SiteSetting.content_security_policy_collect_reports
  end

  def build
    policy = ActionDispatch::ContentSecurityPolicy.new

    @directives.each do |directive, sources|
      if sources.is_a?(Array)
        policy.public_send(directive, *sources)
      else
        policy.public_send(directive, sources)
      end
    end

    policy.build
  end

  private

  def script_src
    sources = [:self, :unsafe_eval]

    sources << :https if SiteSetting.force_https
    sources << Discourse.asset_host if Discourse.asset_host.present?
    sources << 'www.google-analytics.com' if SiteSetting.ga_universal_tracking_code.present?
    sources << 'www.googletagmanager.com' if SiteSetting.gtm_container_id.present?

    sources.concat(SiteSetting.content_security_policy_script_src.split('|'))
  end
end
