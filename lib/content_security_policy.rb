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
      worker_src: [:self, :blob],
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

  SCRIPT_ASSET_DIRECTORIES = [
    # [dir, can_use_s3_cdn, can_use_cdn]
    ['/assets/',             true, true],
    ['/brotli_asset/',       true, true],
    ['/extra-locales/',      false, false],
    ['/highlight-js/',       false, true],
    ['/javascripts/',        false, true],
    ['/plugins/',            false, true],
    ['/theme-javascripts/',  false, true],
    ['/svg-sprite/',         false, true],
  ]

  def script_assets(base = base_url, s3_cdn = GlobalSetting.s3_cdn_url, cdn = GlobalSetting.cdn_url)
    SCRIPT_ASSET_DIRECTORIES.map do |dir, can_use_s3_cdn, can_use_cdn|
      if can_use_s3_cdn && s3_cdn
        s3_cdn + dir
      elsif can_use_cdn && cdn
        cdn + dir
      else
        base + dir
      end
    end
  end

  def script_src
    sources = [
      :unsafe_eval,
      "#{base_url}/logs/",
      "#{base_url}/sidekiq/",
      "#{base_url}/mini-profiler-resources/",
    ]

    sources.concat(script_assets)

    sources << 'https://www.google-analytics.com' if SiteSetting.ga_universal_tracking_code.present?
    sources << 'https://www.googletagmanager.com' if SiteSetting.gtm_container_id.present?

    sources.concat(SiteSetting.content_security_policy_script_src.split('|'))
  end

  def base_url
    @base_url ||= Rails.env.development? ? request.host_with_port : Discourse.base_url
  end
end
