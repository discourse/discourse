# frozen_string_literal: true

# Server-side math rendering support for discourse-math plugin
# Provides validation, sanitization, and caching for math expressions
module DiscourseMath
  class MathRenderer
    # Maximum length for math expressions to prevent DoS
    MAX_EXPRESSION_LENGTH = 10_000

    # Characters that could indicate XSS attempts in math
    DANGEROUS_PATTERNS = [/<script/i, /javascript:/i, /on\w+\s*=/i, /data:/i].freeze

    class Error < StandardError
    end

    class ValidationError < Error
    end

    class RenderError < Error
    end

    class << self
      # Render a math expression to HTML
      # @param expression [String] The math expression to render
      # @param options [Hash] Rendering options
      # @option options [Boolean] :display_mode Whether to render in display mode
      # @option options [String] :provider The math provider ("mathjax" or "katex")
      # @return [String, nil] The rendered HTML or nil if rendering is not available
      def render(expression, options = {})
        return nil if expression.blank?

        validate!(expression)
        sanitized = sanitize(expression)

        # Server-side rendering would go here
        # For now, we return nil to indicate client-side rendering should be used
        # Future implementation could use MiniRacer to run MathJax/KaTeX server-side
        nil
      end

      # Validate a math expression
      # @param expression [String] The math expression to validate
      # @raise [ValidationError] If the expression is invalid
      # @return [Boolean] true if valid
      def validate!(expression)
        raise ValidationError, "Expression cannot be blank" if expression.blank?

        if expression.length > MAX_EXPRESSION_LENGTH
          raise ValidationError, "Expression exceeds maximum length of #{MAX_EXPRESSION_LENGTH}"
        end

        DANGEROUS_PATTERNS.each do |pattern|
          if expression.match?(pattern)
            raise ValidationError, "Expression contains potentially dangerous content"
          end
        end

        true
      end

      # Check if an expression is valid without raising
      # @param expression [String] The math expression to check
      # @return [Boolean] true if valid, false otherwise
      def valid?(expression)
        validate!(expression)
        true
      rescue ValidationError
        false
      end

      # Sanitize a math expression for safe rendering
      # @param expression [String] The math expression to sanitize
      # @return [String] The sanitized expression
      def sanitize(expression)
        return "" if expression.blank?

        # Remove null bytes and other control characters (except newlines and tabs)
        sanitized = expression.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, "")

        # Normalize line endings
        sanitized = sanitized.gsub(/\r\n?/, "\n")

        # Trim excessive whitespace while preserving structure
        sanitized.strip
      end

      # Extract all math expressions from HTML content
      # @param html [String] The HTML content to extract from
      # @return [Array<Hash>] Array of hashes with :expression, :type (:inline or :block), and :element
      def extract_math_expressions(html)
        return [] if html.blank?

        doc = Nokogiri::HTML5.fragment(html)
        expressions = []

        # Extract inline math (span.math)
        doc
          .css("span.math")
          .each { |elem| expressions << { expression: elem.text, type: :inline, element: elem } }

        # Extract block math (div.math)
        doc
          .css("div.math")
          .each { |elem| expressions << { expression: elem.text, type: :block, element: elem } }

        # Extract asciimath (span.asciimath)
        doc
          .css("span.asciimath")
          .each { |elem| expressions << { expression: elem.text, type: :asciimath, element: elem } }

        expressions
      end

      # Check if content contains any math expressions
      # @param html [String] The HTML content to check
      # @return [Boolean] true if math expressions are present
      def contains_math?(html)
        return false if html.blank?
        html.include?('class="math"') || html.include?('class="asciimath"')
      end

      # Get cache key for a math expression
      # @param expression [String] The math expression
      # @param options [Hash] Rendering options
      # @return [String] The cache key
      def cache_key(expression, options = {})
        provider = options[:provider] || "mathjax"
        display_mode = options[:display_mode] ? "block" : "inline"
        hash = Digest::SHA256.hexdigest("#{provider}:#{display_mode}:#{expression}")
        "discourse_math:rendered:#{hash}"
      end

      # Get rendered math from cache
      # @param expression [String] The math expression
      # @param options [Hash] Rendering options
      # @return [String, nil] The cached HTML or nil
      def from_cache(expression, options = {})
        key = cache_key(expression, options)
        Discourse.cache.read(key)
      end

      # Store rendered math in cache
      # @param expression [String] The math expression
      # @param html [String] The rendered HTML
      # @param options [Hash] Rendering options
      # @return [Boolean] true if stored successfully
      def to_cache(expression, html, options = {})
        key = cache_key(expression, options)
        # Cache for 1 week since math rendering is deterministic
        Discourse.cache.write(key, html, expires_in: 1.week)
        true
      end

      # Clear cached rendering for an expression
      # @param expression [String] The math expression
      # @param options [Hash] Rendering options
      # @return [Boolean] true if cleared
      def clear_cache(expression, options = {})
        key = cache_key(expression, options)
        Discourse.cache.delete(key)
        true
      end

      # Statistics about math usage
      # @return [Hash] Statistics hash
      def stats
        {
          enabled: SiteSetting.discourse_math_enabled,
          provider: SiteSetting.discourse_math_provider,
          asciimath_enabled: SiteSetting.discourse_math_enable_asciimath,
          accessibility_enabled: SiteSetting.discourse_math_enable_accessibility,
        }
      end
    end
  end
end
