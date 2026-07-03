# frozen_string_literal: true
require "content_security_policy"

class ContentSecurityPolicy
  class Default
    attr_reader :directives

    def initialize
      @directives =
        {}.tap do |directives|
          directives[:upgrade_insecure_requests] = [] if SiteSetting.force_https
          directives[:base_uri] = [:self]
          directives[:object_src] = [:none]
          directives[:script_src] = script_src
          directives[:worker_src] = worker_src
          directives[:frame_ancestors] = frame_ancestors if restrict_embed?
          directives[:manifest_src] = ["'self'"]
          directives[:report_uri] = [report_uri] if report_uri.present?
        end
    end

    private

    def script_src
      sources = %w['strict-dynamic' 'wasm-unsafe-eval']
      sources << "'report-sample'" if report_uri.present?
      sources
    end

    def report_uri
      SiteSetting.content_security_policy_report_uri.presence
    end

    def worker_src
      [:self, "blob:", *worker_asset_host]
    end

    def worker_asset_host
      if GlobalSetting.use_s3? && GlobalSetting.s3_cdn_url.present?
        s3_cdn = GlobalSetting.s3_asset_cdn_url.presence || GlobalSetting.s3_cdn_url
        ["#{s3_cdn}/assets/"]
      elsif GlobalSetting.cdn_url.present?
        ["#{GlobalSetting.cdn_url}#{Discourse.base_path}/assets/"]
      else
        []
      end
    end

    def frame_ancestors
      ["'self'", *EmbeddableHost.pluck(:host).map { |host| "https://#{host}" }]
    end

    def restrict_embed?
      SiteSetting.content_security_policy_frame_ancestors && !SiteSetting.embed_any_origin
    end
  end
end
