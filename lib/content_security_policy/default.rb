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
          directives[:worker_src] = []
          directives[:frame_ancestors] = frame_ancestors if restrict_embed?
          directives[:manifest_src] = ["'self'"]
        end
    end

    private

    def script_src
      ["'strict-dynamic'"]
    end

    def frame_ancestors
      ["'self'", *EmbeddableHost.pluck(:host).map { |host| "https://#{host}" }]
    end

    def restrict_embed?
      SiteSetting.content_security_policy_frame_ancestors && !SiteSetting.embed_any_origin
    end
  end
end
