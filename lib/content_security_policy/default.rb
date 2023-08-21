# frozen_string_literal: true
require "content_security_policy"

class ContentSecurityPolicy
  class Default
    attr_reader :directives

    def initialize(base_url:)
      @base_url = base_url
      @directives =
        {}.tap do |directives|
          directives[:upgrade_insecure_requests] = [] if SiteSetting.force_https
          directives[:base_uri] = [:self]
          directives[:object_src] = [:none]
          directives[:script_src] = script_src
          directives[:worker_src] = worker_src
          directives[
            :report_uri
          ] = report_uri if SiteSetting.content_security_policy_collect_reports
          directives[:frame_ancestors] = frame_ancestors if restrict_embed?
          directives[:manifest_src] = ["'self'"]
        end
    end

    private

    def base_url
      @base_url
    end

    SCRIPT_ASSET_DIRECTORIES = [
      # [dir, can_use_s3_cdn, can_use_cdn, for_worker]
      ["/assets/", true, true, true],
      ["/brotli_asset/", true, true, true],
      ["/extra-locales/", false, false, false],
      ["/highlight-js/", false, true, false],
      ["/javascripts/", false, true, true],
      ["/plugins/", false, true, true],
      ["/theme-javascripts/", false, true, false],
      ["/svg-sprite/", false, true, false],
    ]

    def script_assets(
      base = base_url,
      s3_cdn = GlobalSetting.s3_asset_cdn_url.presence || GlobalSetting.s3_cdn_url,
      cdn = GlobalSetting.cdn_url,
      worker: false
    )
      SCRIPT_ASSET_DIRECTORIES
        .map do |dir, can_use_s3_cdn, can_use_cdn, for_worker|
          next if worker && !for_worker
          if can_use_s3_cdn && s3_cdn
            s3_cdn + dir
          elsif can_use_cdn && cdn
            cdn + Discourse.base_path + dir
          else
            base + dir
          end
        end
        .compact
    end

    def script_src
      [
        "#{base_url}/logs/",
        "#{base_url}/sidekiq/",
        "#{base_url}/mini-profiler-resources/",
        *script_assets,
      ].tap do |sources|
        sources << :report_sample if SiteSetting.content_security_policy_collect_reports
        sources << :unsafe_eval if Rails.env.development? # TODO remove this once we have proper source maps in dev

        # Support Ember CLI Live reload
        if Rails.env.development?
          sources << "#{base_url}/ember-cli-live-reload.js"
          sources << "#{base_url}/_lr/"
        end

        # we need analytics.js still as gtag/js is a script wrapper for it
        if SiteSetting.ga_universal_tracking_code.present?
          sources << "https://www.google-analytics.com/analytics.js"
        end
        if SiteSetting.ga_universal_tracking_code.present? && SiteSetting.ga_version == "v4_gtag"
          sources << "https://www.googletagmanager.com/gtag/js"
        end
        if SiteSetting.gtm_container_id.present?
          sources << "https://www.googletagmanager.com/gtm.js"
        end

        sources << "'#{SplashScreenHelper.fingerprint}'" if SiteSetting.splash_screen
      end
    end

    def worker_src
      [
        "'self'", # For service worker
        *script_assets(worker: true),
      ]
    end

    def report_uri
      "#{base_url}/csp_reports"
    end

    def frame_ancestors
      ["'self'", *EmbeddableHost.pluck(:host).map { |host| "https://#{host}" }]
    end

    def restrict_embed?
      SiteSetting.content_security_policy_frame_ancestors && !SiteSetting.embed_any_origin
    end
  end
end
