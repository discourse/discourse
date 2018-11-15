# frozen_string_literal: true
require_dependency 'global_path'

class ContentSecurityPolicy
  include GlobalPath

  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)
      _, headers, _ = response = @app.call(env)

      return response unless html_response?(headers) && ContentSecurityPolicy.enabled?

      policy = ContentSecurityPolicy.new(request).build
      headers['Content-Security-Policy'] = policy if SiteSetting.content_security_policy
      headers['Content-Security-Policy-Report-Only'] = policy if SiteSetting.content_security_policy_report_only

      response
    end

    private

    def html_response?(headers)
      headers['Content-Type'] && headers['Content-Type'] =~ /html/
    end
  end

  def self.enabled?
    SiteSetting.content_security_policy || SiteSetting.content_security_policy_report_only
  end

  def initialize(request = nil)
    @request = request
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

  attr_reader :request

  SCRIPT_ASSET_DIRECTORIES = %w(
    /assets/
    /brotli_asset/
    /extra-locales/
    /highlight-js/
    /javascripts/
    /theme-javascripts/
  )

  def script_assets(base = base_url)
    SCRIPT_ASSET_DIRECTORIES.map { |dir| base + dir }
  end

  def script_src
    sources = [
      :unsafe_eval,
      "#{base_url}/logs/",
      "#{base_url}/sidekiq/",
      "#{base_url}/mini-profiler-resources/",
    ]

    sources.concat(script_assets)
    sources.concat(script_assets(GlobalSetting.cdn_url)) if GlobalSetting.cdn_url
    sources.concat(script_assets(GlobalSetting.s3_cdn_url)) if GlobalSetting.s3_cdn_url

    sources << 'https://www.google-analytics.com' if SiteSetting.ga_universal_tracking_code.present?
    sources << 'https://www.googletagmanager.com' if SiteSetting.gtm_container_id.present?

    sources.concat(SiteSetting.content_security_policy_script_src.split('|'))
  end

  def protocal
    @protocal ||= SiteSetting.force_https ? 'https://' : 'http://'
  end

  def with_protocal(url)
    protocal + url
  end

  def base_url
    @base_url ||= Rails.env.development? ? with_protocal(request.host_with_port) : Discourse.base_url
  end
end
