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
          directives[:worker_src] = []
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
      ["/extra-locales/", false, false, false],
      ["/highlight-js/", false, true, false],
      ["/javascripts/", false, true, true],
      ["/plugins/", false, true, true],
      ["/theme-javascripts/", false, true, false],
      ["/svg-sprite/", false, true, false],
    ].freeze

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
      sources = ["'strict-dynamic'"]
      sources << :report_sample if SiteSetting.content_security_policy_collect_reports

      sources
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
