# frozen_string_literal: true

require "yaml"

module DiscourseMcp
  module Tools
    module AuthoringGuideSupport
      ROOTS = %w[.skills docs/developer-guides].freeze
      MAX_BYTES = 256 * 1024

      module_function

      def available?
        ROOTS.any? { |directory| Rails.root.join(directory).directory? }
      end

      def read_path(path)
        if Pathname.new(path).absolute?
          raise ToolError, I18n.t("mcp.errors.authoring_guide_unavailable")
        end

        root = Rails.root.realpath
        file = root.join(path).realpath
        allowed = ROOTS.any? { |directory| file.to_s.start_with?(root.join(directory).to_s + "/") }
        unless allowed && file.file? && file.extname == ".md" && file.size <= MAX_BYTES
          raise ToolError, I18n.t("mcp.errors.authoring_guide_unavailable")
        end

        file
      rescue Errno::ENOENT, Errno::ENOTDIR, Errno::EACCES, Errno::ELOOP, ArgumentError
        raise ToolError, I18n.t("mcp.errors.authoring_guide_unavailable")
      end

      def metadata(content)
        frontmatter = content.match(/\A---\s*\n(.*?)\n---/m)&.[](1)
        value = frontmatter ? YAML.safe_load(frontmatter) : nil
        value.is_a?(Hash) ? value : {}
      rescue Psych::Exception
        {}
      end
    end

    class ListAuthoringGuides
      REQUIRED_SCOPES = [Scopes::REPOSITORY_READ].freeze
      CONTENT = :none
      OUTPUT_SCHEMA =
        OutputSchema.object(
          skills: OutputSchema::OBJECT_ARRAY,
          theme_guides: OutputSchema::STRING_ARRAY,
          roots: OutputSchema::STRING_ARRAY,
        )

      def self.call(arguments:, request_context:)
        request_context.guardian.ensure_is_admin!
        skills =
          Rails
            .root
            .glob(".skills/*/SKILL.md")
            .sort
            .filter_map do |file|
              path = file.relative_path_from(Rails.root).to_s
              content = AuthoringGuideSupport.read_path(path).read
              metadata = AuthoringGuideSupport.metadata(content)
              {
                name: metadata["name"] || file.parent.basename.to_s,
                description: metadata["description"].to_s,
                path: path,
              }
            rescue ToolError
              nil
            end
        theme_guides =
          Rails
            .root
            .glob("docs/developer-guides/docs/*theme*/*.md")
            .sort
            .map { |file| file.relative_path_from(Rails.root).to_s }
        ToolHelpers.text_and_structured(
          skills: skills,
          theme_guides: theme_guides,
          roots: AuthoringGuideSupport::ROOTS,
        )
      end
    end

    class ReadAuthoringGuide
      REQUIRED_SCOPES = [Scopes::REPOSITORY_READ].freeze
      CONTENT = :none
      OUTPUT_SCHEMA =
        OutputSchema.object(
          path: OutputSchema::STRING,
          content: OutputSchema::STRING,
          start_line: OutputSchema::INTEGER,
          total_lines: OutputSchema::INTEGER,
          next_line: OutputSchema::INTEGER_OR_NULL,
        )

      def self.call(arguments:, request_context:)
        request_context.guardian.ensure_is_admin!
        path = AuthoringGuideSupport.read_path(arguments.fetch("path"))
        start_line = [arguments.fetch("start_line", 1).to_i, 1].max
        max_lines = arguments.fetch("max_lines", 200).to_i.clamp(1, 400)
        lines = path.readlines
        selected = lines.drop(start_line - 1).first(max_lines)
        next_line = start_line + selected.length
        ToolHelpers.text_and_structured(
          path: path.relative_path_from(Rails.root.realpath).to_s,
          content: selected.join,
          start_line: start_line,
          total_lines: lines.length,
          next_line: next_line <= lines.length ? next_line : nil,
        )
      end
    end
  end
end
