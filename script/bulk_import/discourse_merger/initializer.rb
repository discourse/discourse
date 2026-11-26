# frozen_string_literal: true

require_relative "inventory"
require_relative "template_exporter"
require_relative "runner"

module BulkImport::DiscourseMerge
  class Initializer
    def initialize(
      directory,
      input: $stdin,
      output: $stdout,
      progress: Progress.new(output: output)
    )
      @directory, @input, @output = Pathname.new(directory).expand_path, input, output
      @progress = progress
    end

    def ask(label, default = nil)
      @output.print("#{label}#{default.nil? ? "" : " [#{default}]"}: ")
      @output.flush
      answer = @input.gets
      raise Error, "Setup interrupted; existing decisions have been preserved" unless answer
      answer = answer.strip
      answer.empty? ? default : answer
    end

    def run
      @directory.mkpath
      File.chmod(0o700, @directory)
      path = @directory.join("merge.yml")
      configuration =
        if path.exist?
          @progress.start("saved configuration")
          @progress.say("Using #{path}; edit this file to change setup")
          Configuration.new(@directory)
        else
          @progress.start("project configuration")
          contents = collect_configuration.to_yaml
          Configuration
            .new(@directory, contents: contents)
            .tap do
              Artifacts.write(path, contents, replace: false)
              @progress.say("Saved #{path}")
            end
        end
      Runner.new(configuration, progress: @progress).preflight(setup_only: true)
      if @directory.join("mappings").exist? || @directory.join("mappings.xlsx").exist?
        @progress.say("Existing mapping decisions preserved in #{@directory}")
        return
      end
      @output.puts("Check the site titles and topic counts above against the backups you restored.")

      @progress.start("source category choices")
      inventory = Inventory.new(configuration, progress: @progress)
      source = inventory.source_categories
      @output.puts("Source categories (ID and path)")
      source.each_key do |id|
        @output.puts("  #{id}  #{TemplateExporter.path(id, source).join(" > ")}")
      end
      parent = ask("Place source categories under a parent path (blank to retain paths)", "")
      excluded =
        ask(
          "Explicitly exclude source category IDs, separated by commas (descendants need their own decisions)",
          "",
        ).split(",").map { |id| Integer(id.strip) }
      unless (excluded - source.keys).empty?
        raise Error, "Unknown excluded category IDs: #{excluded - source.keys}"
      end
      captured = inventory.capture
      @progress.start("mapping templates")
      TemplateExporter.new(configuration, captured).export(
        parent_path: parent,
        excluded_category_ids: excluded,
      )
      @progress.say(
        "Edit #{@directory.join("mappings/categories.csv")} and the other mapping files before full preflight",
      )
    end

    def collect_configuration
      @output.puts(
        "Choose docker for the all-in-one Discourse container with local PostgreSQL and peer authentication.",
      )
      mode = ask("Database setup (docker or custom)", "docker")
      raise Error, "Choose docker or custom for database setup" if %w[docker custom].exclude?(mode)

      data = %w[source destination].to_h { |side| [side, collect_connection(side, mode)] }
      @output.puts("Forum URLs include http:// or https:// and a port if your browser uses one.")
      data["source_url"] = ask("Original source forum URL")
      data["destination_url"] = ask("Destination forum URL (where rewritten links should point)")
      data["namespace"] = ask(
        "Short label for imported IDs (such as the source forum name)",
        "incoming",
      )
      @output.puts(
        "Choose copy for local upload files or preserve_remote to keep URLs served by the existing media hosts, or preuploaded to prepare hosted S3 files before launch.",
      )
      data["upload_mode"] = ask("Upload mode (copy, preserve_remote, or preuploaded)", "copy")
      if data["upload_mode"] == "copy"
        data["source_upload_root"] = ask(
          "Source uploads folder inside the merge container",
          mode == "docker" ? "/shared/incoming-uploads" : nil,
        )
        data["destination_upload_root"] = ask(
          "Destination uploads folder inside the merge container",
          "/shared/uploads/default",
        )
      end
      if data["upload_mode"] == "preuploaded"
        %w[source destination].each do |side|
          root = ask("#{side.capitalize} extracted upload root (blank for already-hosted media)")
          data["#{side}_upload_root"] = root if root && !root.empty?
        end
      end
      data["include_private_messages"] = yes?(ask("Include private messages? yes/no", "yes"))
      data["import_tags"] = yes?(ask("Import incoming tags? yes/no", "yes"))
      data["max_category_depth"] = Integer(ask("Maximum category depth", "3")) if mode == "custom"
      data
    end

    def collect_connection(side, mode)
      label =
        (
          if side == "source"
            "Source PostgreSQL database (the prepared source)"
          else
            "Destination PostgreSQL database"
          end
        )
      name = ask(label, side == "source" ? "incoming_forum" : "discourse")
      connection = {
        "dbname" => name,
        "host" => "/var/run/postgresql",
        "port" => 5432,
        "user" => "discourse",
      }
      return connection if mode == "docker"

      host = ask("#{side} PostgreSQL hostname or socket path", connection.fetch("host"))
      while host.include?("://")
        @output.puts("Enter a PostgreSQL hostname or socket path. The forum URL comes later.")
        host = ask("#{side} PostgreSQL hostname or socket path", connection.fetch("host"))
      end
      connection["host"] = host
      connection["port"] = Integer(ask("#{side} PostgreSQL port", "5432"))
      connection["user"] = ask("#{side} PostgreSQL user", "discourse")
      password_env =
        ask("#{side} password environment variable (blank for peer authentication)", "")
      connection["password_env"] = password_env unless password_env.empty?
      connection
    end

    def yes?(answer)
      return true if answer == "yes"
      return false if answer == "no"
      raise Error, "Answer yes or no"
    end
  end
end
