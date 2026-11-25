# frozen_string_literal: true

require "open3"

module DiscourseMcp
  module Tools
    module SourceSupport
      ROOTS = %w[
        app
        frontend
        lib
        plugins
        spec
        docs
        .skills
        config/initializers
        config/environments
        config/locales
      ].freeze
      FILES = %w[config/routes.rb config/site_settings.yml].freeze
      EXTENSIONS = %w[
        .rb
        .js
        .ts
        .gjs
        .gts
        .mjs
        .cjs
        .scss
        .css
        .hbs
        .md
        .yml
        .yaml
        .json
        .erb
        .html
      ].freeze
      MAX_BYTES = 256 * 1024
      MAX_FILE_BYTES = 2 * 1024 * 1024
      COMMAND_TIMEOUT_SECONDS = 5
      SEARCH_PATHS =
        (
          ROOTS.flat_map do |root|
            EXTENSIONS.map { |extension| ":(glob)#{root}/**/*#{extension}" }
          end + FILES
        ).freeze

      module_function

      def available?
        return true if @available && @availability_root == Rails.root

        @available =
          begin
            Rails.root.join(".git").exist? &&
              git("rev-parse", "--is-inside-work-tree").first.strip == "true"
          rescue ToolError
            false
          end
        @availability_root = Rails.root
        @available
      end

      def git(*arguments, truncate: false, max_bytes: MAX_BYTES, literal_pathspecs: true)
        Open3.popen3(
          {
            "GIT_NO_LAZY_FETCH" => "1",
            "GIT_OPTIONAL_LOCKS" => "0",
            "GIT_LITERAL_PATHSPECS" => literal_pathspecs ? "1" : "0",
          },
          "git",
          "-C",
          Rails.root.to_s,
          *arguments,
          pgroup: true,
        ) do |input, output, errors, process|
          input.close
          reader =
            Thread.new do
              data = output.read(max_bytes + 1).to_s
              kill(process.pid) if data.bytesize > max_bytes
              data
            end
          reader.name = "mcp-source-stdout"
          error_reader =
            Thread.new do
              data = errors.read(MAX_BYTES + 1).to_s
              kill(process.pid) if data.bytesize > MAX_BYTES
            end
          error_reader.name = "mcp-source-stderr"
          unless process.join(COMMAND_TIMEOUT_SECONDS)
            kill(process.pid)
            process.join
            raise ToolError, I18n.t("mcp.errors.source_unavailable")
          end
          data = reader.value
          error_reader.value
          if data.bytesize > max_bytes
            raise ToolError, I18n.t("mcp.errors.source_too_large") unless truncate
            return data.byteslice(0, max_bytes).force_encoding(Encoding::UTF_8).scrub, true
          end
          succeeded =
            process.value.success? || (arguments.first == "grep" && process.value.exitstatus == 1)
          raise ToolError, I18n.t("mcp.errors.source_unavailable") unless succeeded
          [data.dup.force_encoding(Encoding::UTF_8).scrub, false]
        ensure
          [reader, error_reader].compact.each do |thread|
            thread.kill if thread.alive?
            thread.join
          end
        end
      rescue Errno::ENOENT
        raise ToolError, I18n.t("mcp.errors.source_unavailable")
      end

      def kill(pid)
        Process.kill("KILL", -pid)
      rescue Errno::ESRCH
        nil
      end

      def version
        reported = Discourse.git_version
        head = git("rev-parse", "HEAD").first.strip
        revision =
          if reported.to_s.match?(/\A[0-9a-f]{40}\z/)
            git("rev-parse", "--verify", "#{reported}^{commit}").first.strip
          else
            head
          end
        {
          site_version: Discourse::VERSION::STRING,
          server_reported_revision: reported,
          source_revision: revision,
          revision_basis:
            revision == reported ? "server_reported_revision" : "checkout_head_fallback",
          checkout_revision: head,
          working_tree_changed: git("status", "--porcelain", "--untracked-files=no").first.present?,
          public_repository: "https://github.com/discourse/discourse",
          public_permalink_verified: false,
          runtime_snapshot_verified: false,
          note:
            "Committed mode reads the reported revision, not latest main. Working-tree mode reads tracked files currently on disk, which may include unpublished edits. Neither verifies what every running process has loaded. Separately checked-out plugin repositories are not included. Links use the public core repository; unpublished local commits may not exist there.",
        }
      end

      def path(value)
        candidate = Pathname.new(value.to_s)
        raise ToolError, I18n.t("mcp.errors.source_path_unavailable") if candidate.absolute?
        normalized = candidate.cleanpath.to_s
        allowed =
          FILES.include?(normalized) || ROOTS.any? { |root| normalized.start_with?(root + "/") }
        unless allowed && EXTENSIONS.include?(File.extname(normalized)) &&
                 !normalized.include?("\0")
          raise ToolError, I18n.t("mcp.errors.source_path_unavailable")
        end
        normalized
      rescue ArgumentError
        raise ToolError, I18n.t("mcp.errors.source_path_unavailable")
      end

      def read(path, mode, revision)
        if mode == "working_tree"
          git("ls-files", "--error-unmatch", "--", path)
          file = Rails.root.join(path)
          unless file.file? && !file.symlink? &&
                   file.realpath.to_s.start_with?(Rails.root.realpath.to_s + "/")
            raise ToolError, I18n.t("mcp.errors.source_path_unavailable")
          end
          self.path(file.realpath.relative_path_from(Rails.root.realpath).to_s)
          raise ToolError, I18n.t("mcp.errors.source_too_large") if file.size > MAX_FILE_BYTES
          content = file.read(MAX_FILE_BYTES + 1)
          if content.bytesize > MAX_FILE_BYTES
            raise ToolError, I18n.t("mcp.errors.source_too_large")
          end
          content.force_encoding(Encoding::UTF_8).scrub
        else
          entry = git("ls-tree", revision, "--", path).first
          unless entry.start_with?("100644 ", "100755 ")
            raise ToolError, I18n.t("mcp.errors.source_path_unavailable")
          end
          git("show", "#{revision}:#{path}", max_bytes: MAX_FILE_BYTES).first
        end
      rescue Errno::ENOENT, Errno::EACCES, Errno::ELOOP
        raise ToolError, I18n.t("mcp.errors.source_path_unavailable")
      end

      def public_url(revision, path, line)
        "https://github.com/discourse/discourse/blob/#{revision}/#{URI::DEFAULT_PARSER.escape(path)}#L#{line}"
      end
    end

    class SourceVersion
      REQUIRED_SCOPES = [Scopes::REPOSITORY_READ].freeze
      CONTENT = :none
      OUTPUT_SCHEMA = OutputSchema.object(source: OutputSchema::OBJECT)

      def self.call(arguments:, request_context:)
        request_context.guardian.ensure_is_admin!
        ToolHelpers.text_and_structured(source: SourceSupport.version)
      end
    end

    class ReadSource
      REQUIRED_SCOPES = [Scopes::REPOSITORY_READ].freeze
      CONTENT = :none
      OUTPUT_SCHEMA =
        OutputSchema.object(
          source: OutputSchema::OBJECT,
          path: OutputSchema::STRING,
          mode: OutputSchema::STRING,
          content: OutputSchema::STRING,
          start_line: OutputSchema::INTEGER,
          total_lines: OutputSchema::INTEGER,
          next_line: OutputSchema::INTEGER_OR_NULL,
          public_url: OutputSchema::STRING_OR_NULL,
        )

      def self.call(arguments:, request_context:)
        request_context.guardian.ensure_is_admin!
        path = SourceSupport.path(arguments.fetch("path"))
        source = SourceSupport.version
        mode = arguments.fetch("mode", "committed")
        lines = SourceSupport.read(path, mode, source[:source_revision]).lines
        start_line = [arguments.fetch("start_line", 1).to_i, 1].max
        selected =
          lines.drop(start_line - 1).first(arguments.fetch("max_lines", 150).to_i.clamp(1, 400))
        if selected.join.bytesize > SourceSupport::MAX_BYTES
          raise ToolError, I18n.t("mcp.errors.source_too_large")
        end
        next_line = start_line + selected.size
        ToolHelpers.text_and_structured(
          source: source,
          path: path,
          mode: mode,
          content: selected.join,
          start_line: start_line,
          total_lines: lines.size,
          next_line: next_line <= lines.size ? next_line : nil,
          public_url:
            (
              if mode == "committed"
                SourceSupport.public_url(source[:source_revision], path, start_line)
              else
                nil
              end
            ),
        )
      end
    end

    class SearchSource
      REQUIRED_SCOPES = [Scopes::REPOSITORY_READ].freeze
      CONTENT = :none
      OUTPUT_SCHEMA =
        OutputSchema.object(
          source: OutputSchema::OBJECT,
          mode: OutputSchema::STRING,
          matches: OutputSchema::OBJECT_ARRAY,
          truncated: OutputSchema::BOOLEAN,
        )

      def self.call(arguments:, request_context:)
        request_context.guardian.ensure_is_admin!
        source = SourceSupport.version
        mode = arguments.fetch("mode", "committed")
        command = ["grep", "-n", "-I", "-F", "--no-color", "-e", arguments.fetch("query")]
        command << source[:source_revision] if mode == "committed"
        output, truncated =
          SourceSupport.git(
            *command,
            "--",
            *SourceSupport::SEARCH_PATHS,
            truncate: true,
            literal_pathspecs: false,
          )
        limit = arguments.fetch("max_results", 20).to_i.clamp(1, 50)
        matches =
          output.lines.filter_map do |line|
            line = line.delete_prefix("#{source[:source_revision]}:") if mode == "committed"
            path, number, content = line.split(":", 3)
            next unless number&.match?(/\A\d+\z/)
            begin
              SourceSupport.path(path)
              if mode == "working_tree"
                file = Rails.root.join(path)
                if file.symlink? || !file.realpath.to_s.start_with?(Rails.root.realpath.to_s + "/")
                  next
                end
                SourceSupport.path(file.realpath.relative_path_from(Rails.root.realpath).to_s)
              end
            rescue ToolError, Errno::ENOENT
              next
            end
            {
              path: path,
              line: number.to_i,
              content: content.to_s.chomp.truncate(1000),
              public_url:
                (
                  if mode == "committed"
                    SourceSupport.public_url(source[:source_revision], path, number)
                  else
                    nil
                  end
                ),
            }
          end
        ToolHelpers.text_and_structured(
          source: source,
          mode: mode,
          matches: matches.first(limit),
          truncated: truncated || matches.size > limit,
        )
      end
    end
  end
end
