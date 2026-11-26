# frozen_string_literal: true

require "optparse"
require "shellwords"
require_relative "inventory"
require_relative "planner"
require_relative "progress"

module BulkImport::DiscourseMerge
  class CLI
    COMMANDS = %w[
      init
      export
      export-workbook
      prepare-uploads
      preflight
      plan
      apply
      verify
      report
    ].freeze

    def self.run(arguments)
      command = arguments.shift
      options = { topic_categories: [] }
      parser =
        OptionParser.new do |flags|
          flags.banner = "Usage: cli.rb #{COMMANDS.join("|")} --directory PROJECT [options]"
          flags.on("--directory PATH", "Private merge project directory") do |value|
            options[:directory] = value
          end
          flags.on(
            "--settings PATH",
            "Private uploads importer YAML for prepare-uploads",
          ) { |value| options[:settings] = value }
          flags.on("--setup-only", "Preflight prepared environments before mappings exist") do
            options[:setup_only] = true
          end
          flags.on(
            "--topic-categories IDS",
            Array,
            "Export topic rows from these comma-separated category IDs",
          ) { |values| options[:topic_categories] = values.map { |value| Integer(value) } }
          flags.on("--plan-sha256 HASH", "Apply the reviewed plan with this SHA-256") do |value|
            options[:plan_sha256] = value
          end
          flags.on(
            "--approve-access-changes",
            "Approve the access expansions in the reviewed plan",
          ) { options[:approve_access_changes] = true }
          flags.on("-h", "--help") do
            puts flags
            return 0
          end
        end
      if command.nil? || %w[-h --help].include?(command)
        puts parser
        return 0
      end
      parser.parse!(arguments)
      raise Error, parser.to_s unless options[:directory] && arguments.empty?
      raise Error, "Unknown command: #{command}" if COMMANDS.exclude?(command)
      if (command == "prepare-uploads") != !!options[:settings]
        raise Error, "prepare-uploads requires --settings PATH"
      end
      if options[:setup_only] && command != "preflight"
        raise Error, "--setup-only is available with preflight"
      end
      if options[:approve_access_changes] && command != "apply"
        raise Error, "--approve-access-changes is available with apply"
      end
      directory = Pathname.new(options[:directory]).expand_path
      progress = Progress.new
      if command == "init"
        require_relative "initializer"
        directory.mkpath
        File.chmod(0o700, directory)
        progress.open_log(directory, command)
        Initializer.new(directory, progress: progress).run
        configuration = Configuration.new(directory)
        if configuration.preuploaded?
          progress.say("Review preupload_locations in merge.yml against the hosting configuration before preparing uploads.")
        end
        progress.say("Next after editing mappings: #{after_mappings(configuration)}")
        return 0
      end
      unless directory.directory?
        raise Error, "Project directory #{directory} does not exist; run init or create merge.yml"
      end
      progress.open_log(directory, command)
      if command == "report"
        require_relative "customer_report"
        progress.start("verified run evidence")
        report = CustomerReport.new(directory)
        progress.say("Customer report: #{report.write}")
        if report.account_csv_path
          progress.say("Account outcomes: #{report.account_csv_path}")
        else
          progress.say("Account CSV unavailable for this run: incomplete verified account evidence.")
        end
        return 0
      end
      progress.start("project configuration")
      configuration = Configuration.new(directory)
      case command
      when "prepare-uploads"
        raise Error, "Set upload_mode: preuploaded in merge.yml" unless configuration.preuploaded?
        require_relative "../uploads_importer"
        BulkImport::UploadsImporter.prepare_native(
          configuration,
          options.fetch(:settings),
          progress,
        )
        progress.say("Uploads prepared. Next: #{invocation("plan", directory)}")
      when "export"
        TemplateExporter.new(
          configuration,
          Inventory.new(configuration, progress: progress).capture,
        ).export(topic_categories: options[:topic_categories])
        progress.say(
          "Edit #{directory.join("mappings")}, then run #{after_mappings(configuration)}",
        )
      when "export-workbook"
        progress.start("workbook export")
        path = directory.join("mappings.xlsx")
        if path.exist?
          raise Error, "#{path} already exists; keep or move it before exporting a new workbook"
        end
        inventory_path = directory.join("inventory.json")
        inventory =
          (
            if inventory_path.exist?
              JSON.parse(inventory_path.read)
            else
              Inventory.new(configuration, progress: progress).capture
            end
          )
        Workbook.new(configuration, inventory).export(path)
        progress.say("Edit #{path}, then run #{after_mappings(configuration)}")
      when "plan", "apply", "verify", "preflight"
        require_relative "runner"
        runner = Runner.new(configuration, progress: progress)
        case command
        when "plan"
          plan = runner.preflight(write_plan: true)
          hash = Digest::SHA256.file(directory.join("plan.json")).hexdigest
          command = "#{invocation("apply", directory)} --plan-sha256 #{hash}"
          command += " --approve-access-changes" if Audience.expands?(plan)
          progress.say(
            "Review #{directory.join("preview.md")} and snapshot the destination. Then run #{command}",
          )
        when "apply"
          run =
            runner.apply(
              options[:plan_sha256],
              approve_access_changes: options[:approve_access_changes],
            )
          progress.say("Apply verified: #{run}")
          report_backup(run, progress)
        when "verify"
          run = runner.verify
          progress.say("Verification passed: #{run.join("verification.json")}")
          report_backup(run, progress)
        when "preflight"
          runner.preflight(setup_only: options[:setup_only])
          progress.say("Next: #{invocation(options[:setup_only] ? "init" : "plan", directory)}")
        end
      end
      0
    rescue StandardError, LoadError, Interrupt => error
      progress ? progress.failed(error) : warn(error.message)
      error.is_a?(Interrupt) ? 130 : 1
    ensure
      progress&.close
    end

    def self.invocation(command, directory)
      "RAILS_ENV=production bundle exec ruby script/bulk_import/discourse_merger/cli.rb #{command} --directory #{Shellwords.escape(directory.to_s)}"
    end

    def self.after_mappings(configuration)
      return invocation("plan", configuration.directory) unless configuration.preuploaded?
      "#{invocation("prepare-uploads", configuration.directory)} --settings /path/to/private/uploads_importer.yml"
    end

    def self.report_backup(run, progress)
      plan = JSON.parse(run.join("plan.json").read)
      command =
        "RAILS_ENV=production DISCOURSE_BACKUP_LOCATION=local bundle exec ruby script/discourse backup"
      if plan.dig("upload_policy", "mode") == "preuploaded"
        command += " --sql-only"
        if plan.dig("upload_policy", "preserve_destination_uploads")
          progress.say("The SQL-only backup retains destination media and references the prepared incoming files. Restore-test both prefixes.")
        else
          progress.say("Both media inventories were prepared for hosted storage. Restore-test this SQL-only backup.")
        end
      elsif plan.dig("upload_policy", "mode") == "preserve_remote" &&
            !plan.dig("upload_policy", "destination_has_local_uploads")
        command += " --sql-only"
        progress.say(
          "The SQL-only backup keeps media references. Keep the existing media origins available.",
        )
      end
      progress.say("Next: #{command}")
    end
  end
end

exit BulkImport::DiscourseMerge::CLI.run(ARGV) if $PROGRAM_NAME == __FILE__
