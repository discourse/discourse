# frozen_string_literal: true

module Onebox
  class Matcher
    def initialize(url, options = {})
      begin
        @uri = URI(url)
      rescue URI::InvalidURIError
      end

      @options = options
    end

    def ordered_engines
      @ordered_engines ||=
        Engine.engines.sort_by { |e| e.respond_to?(:priority) ? e.priority : 100 }
    end

    def oneboxed
      return if @uri.nil?
      return if @uri.port && !Onebox.options.allowed_ports.include?(@uri.port)
      return if @uri.scheme && !Onebox.options.allowed_schemes.include?(@uri.scheme)

      ordered_engines.find do |engine|
        (
          engine.respond_to?(:handles_content_type?) &&
            engine.handles_content_type?(@options[:content_type]) || engine === @uri
        ) && has_allowed_iframe_origins?(engine)
      end
    end

    def has_allowed_iframe_origins?(engine)
      allowed_regexes = @options[:allowed_iframe_regexes] || []
      engine.iframe_origins.all? { |o| allowed_regexes.any? { |r| o =~ r } }
    end
  end
end
