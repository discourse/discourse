# frozen_string_literal: true

require "liquid"

module ::Blog
  class TemplateRenderer
    PAGES = %w[layout index article about not_found].freeze
    MAX_TEMPLATE_BYTES = 65_536
    TEMPLATE_ROOT = File.expand_path("../../templates", __dir__)

    # Only server-produced fragments may bypass variable escaping.
    class Html < String
    end

    class Context < Liquid::Context
      def evaluate(object)
        value = super
        # Loop tags materialize ranges before the normal render accounting runs.
        raise Liquid::MemoryError, "Range limit exceeded" if value.is_a?(Range) && value.size > 1000
        value
      end
    end

    ENVIRONMENT =
      Liquid::Environment.build(
        tags:
          Liquid::Tags::STANDARD_TAGS.slice(
            "if",
            "unless",
            "case",
            "for",
            "break",
            "continue",
            "assign",
            "capture",
            "comment",
            "raw",
            "cycle",
            "increment",
            "decrement",
          ),
        file_system: Liquid::BlankFileSystem.new,
        error_mode: :strict2,
      ) do |environment|
        environment.default_resource_limits = {
          render_length_limit: 2.megabytes,
          render_score_limit: 100_000,
          assign_score_limit: 256.kilobytes,
          cumulative_render_score_limit: 100_000,
          cumulative_assign_score_limit: 256.kilobytes,
        }
      end

    def self.validate!(source, page: nil)
      unless source.is_a?(String) && source.valid_encoding? && source.bytesize <= MAX_TEMPLATE_BYTES
        raise Discourse::InvalidParameters.new(I18n.t("blog.themes.template_invalid"))
      end
      parse(source)
    rescue Liquid::Error => error
      raise Discourse::InvalidParameters.new(
              I18n.t(
                "blog.themes.template_parse_error",
                error: [page, error.message].compact.join(": "),
              ),
            )
    end

    def self.render(page, assigns, theme:, custom: true, diagnostics: false)
      raise ArgumentError if PAGES.exclude?(page)
      override = custom && theme["template_#{page}"].presence
      source = override || builtin(page)
      if diagnostics
        begin
          return render_source(source, assigns, strict_variables: true)
        rescue Liquid::UndefinedVariable => error
          return(diagnostic(page, error, warning: true) + render_source(source, assigns))
        end
      end
      render_source(source, assigns)
    rescue Liquid::Error => error
      return diagnostic(page, error) if diagnostics
      raise unless override
      Rails.logger.warn("Blog template #{page} failed: #{error.class}")
      render_source(builtin(page), assigns)
    end

    def self.diagnostic(page, error, warning: false)
      message =
        I18n.t(
          "blog.themes.preview_diagnostic",
          template: page,
          line: error.line_number || "?",
          message: error.message,
        )
      "<section class=\"blog__preview\" role=\"alert\" data-template-diagnostic=\"#{warning ? "warning" : "error"}\"><p>#{ERB::Util.html_escape(message)}</p></section>"
    end
    private_class_method :diagnostic

    def self.builtin(page)
      raise ArgumentError if PAGES.exclude?(page)
      File.read(File.join(TEMPLATE_ROOT, "#{page}.liquid"))
    end

    def self.parse(source)
      Liquid::Template.parse(source, environment: ENVIRONMENT, line_numbers: true)
    end
    private_class_method :parse

    def self.render_source(source, assigns, strict_variables: false)
      context = Context.build(environment: ENVIRONMENT, environments: assigns, rethrow_errors: true)
      parse(source).render!(
        context,
        strict_filters: true,
        strict_variables: strict_variables,
        global_filter: ->(value) { value.is_a?(Html) ? value : ERB::Util.html_escape(value.to_s) },
      )
    end
    private_class_method :render_source
  end
end
