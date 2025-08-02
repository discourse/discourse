# frozen_string_literal: true
require "content_security_policy/default"

class ContentSecurityPolicy
  class Builder
    EXTENDABLE_DIRECTIVES = %i[
      base_uri
      frame_ancestors
      manifest_src
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
      frame_src
      img_src
      media_src
      prefetch_src
      style_src
    ].freeze

    def initialize(base_url:)
      @directives = Default.new(base_url: base_url).directives
      @base_url = base_url
    end

    def <<(extension)
      return unless valid_extension?(extension)

      extension.each do |directive, sources|
        extend_directive(normalize_directive(directive), sources)
      end
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

    def normalize_directive(directive)
      directive.to_s.gsub("-", "_").to_sym
    end

    def normalize_source(source)
      if source.starts_with?("/")
        "#{@base_url}#{source}"
      else
        source
      end
    rescue URI::ParseError
      source
    end

    def extend_directive(directive, sources)
      return unless extendable?(directive)

      @directives[directive] ||= []

      sources = Array(sources).map { |s| normalize_source(s) }

      if %w[script_src worker_src].include?(directive.to_s)
        # Strip any sources which are ignored under strict-dynamic
        # If/when we make strict-dynamic the only option, we could print deprecation warnings
        # asking plugin/theme authors to remove the unnecessary config
        sources =
          sources.reject { |s| s == "'unsafe-inline'" || s == "'self'" || !s.start_with?("'") }
      end

      sources.each do |source|
        # mirrors validation check in ActionDispatch::ContentSecurityPolicy https://github.com/rails/rails/blob/5558e72f22fc69c1c407b31ac5fb3b4ce087b542/actionpack/lib/action_dispatch/http/content_security_policy.rb#L337
        if source.include?(";") || source != source.gsub(/[[:space:]]/, "")
          Rails.logger.warn(<<~MSG.squish)
            Skipping invalid Content Security Policy #{directive}: "#{source}".
            Directive values must not contain whitespace or semicolons.
            Please use multiple arguments or other directive methods instead.
          MSG
          next
        end
        @directives[directive] << source
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
