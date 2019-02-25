# frozen_string_literal: true
require_dependency 'content_security_policy/default'

class ContentSecurityPolicy
  class Builder
    EXTENDABLE_DIRECTIVES = %i[
      base_uri
      object_src
      script_src
      worker_src
    ].freeze

    # Make extending these directives no-op, until core includes them in default CSP
    TO_BE_EXTENDABLE = %i[
      connect_src
      default_src
      font_src
      form_action
      frame_ancestors
      frame_src
      img_src
      manifest_src
      media_src
      prefetch_src
      style_src
    ].freeze

    def initialize
      @directives = Default.new.directives
    end

    def <<(extension)
      return unless valid_extension?(extension)

      extension.each { |directive, sources| extend_directive(normalize(directive), sources) }
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

    def normalize(directive)
      directive.to_s.gsub('-', '_').to_sym
    end

    def extend_directive(directive, sources)
      return unless extendable?(directive)

      @directives[directive] ||= []

      if sources.is_a?(Array)
        @directives[directive].concat(sources)
      else
        @directives[directive] << sources
      end

      @directives[directive].delete(:none) if @directives[directive].count > 1
    end

    def extendable?(directive)
      EXTENDABLE_DIRECTIVES.include?(directive)
    end

    def valid_extension?(extension)
      extension.is_a?(Hash)
    end
  end
end
