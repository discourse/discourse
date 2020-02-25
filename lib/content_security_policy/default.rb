# frozen_string_literal: true
require_dependency 'content_security_policy'

class ContentSecurityPolicy
  class Default
    attr_reader :directives

    def initialize
      @directives = {}.tap do |directives|
        directives[:base_uri] = [:none]
        directives[:object_src] = [:none]
        directives[:script_src] = script_src
        directives[:worker_src] = worker_src
        directives[:report_uri] = report_uri if SiteSetting.content_security_policy_collect_reports
      end
    end

    private

    delegate :base_url, to: :ContentSecurityPolicy

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
      [
        :report_sample,
        "#{base_url}/logs/",
        "#{base_url}/sidekiq/",
        "#{base_url}/mini-profiler-resources/",
        *script_assets
      ].tap do |sources|
        sources << :unsafe_eval if Rails.env.development? # TODO remove this once we have proper source maps in dev
        sources << 'https://www.google-analytics.com/analytics.js' if SiteSetting.ga_universal_tracking_code.present?
        sources << 'https://www.googletagmanager.com/gtm.js' if SiteSetting.gtm_container_id.present?
      end
    end

    def worker_src
      [
        :self,
        :blob, # ACE editor registers a service worker with a blob for syntax checking
      ]
    end

    def report_uri
      "#{base_url}/csp_reports"
    end
  end
end
