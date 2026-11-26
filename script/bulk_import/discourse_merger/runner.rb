# frozen_string_literal: true

require_relative "inventory"
require_relative "planner"
require_relative "progress"
require_relative "preuploaded_media"
require "open3"
require "time"

module BulkImport::DiscourseMerge
  class Runner
    INPUT_CHANGED = "Mapping inputs changed; regenerate and review the plan"

    def initialize(configuration, progress: Progress.new)
      @configuration = configuration
      @directory = configuration.directory
      @progress = progress
    end

    def apply(expected_sha256, approve_access_changes: false)
      @progress.start("reviewed plan and run guard")
      path = @directory.join("plan.json")
      lock = File.open(@directory.join("workflow.lock"), "w", 0o600)
      unless lock.flock(File::LOCK_EX | File::LOCK_NB)
        raise Error, "Another workflow command is active"
      end
      if @directory.join("active-run.json").exist?
        active = @directory.join("active-run.json")
        state = JSON.parse(active.read)
        if state["status"] == "verified"
          raise Error, "This project already completed apply; run verify with the same directory"
        end
        @progress.recovery_run = state["run_dir"] || active
        raise Error, "This project already has an active run"
      end
      unless expected_sha256 && path.file?
        raise Error, "Run plan and supply its reviewed SHA-256 with --plan-sha256"
      end
      reviewed = path.binread
      unless Digest::SHA256.hexdigest(reviewed) == expected_sha256
        raise Error,
              "Plan SHA-256 differs from the reviewed hash; review plan.json and preview.md before applying"
      end
      plan = JSON.parse(reviewed)
      if Audience.expands?(plan) && !approve_access_changes
        raise Error,
              "Review the access changes in preview.md and rerun with --approve-access-changes"
      end
      @progress.start("reviewed mapping inputs")
      ensure_reviewed_inputs!(plan)
      @progress.start("destination connection and lock")
      destination_connection = connect("destination")
      Connections.lock!(destination_connection)
      source_connection = open_source(destination_connection)
      validate_setup!(source_connection, destination_connection)
      inventory = capture_inventory(source_connection)
      @progress.start("current mapping decisions")
      planner = Planner.new(@configuration, inventory)
      begin
        current = planner.build
      rescue Error, Errno::ENOENT
        ensure_reviewed_inputs!(plan)
        raise
      end
      unless current == plan
        raise Error, "Plan inputs or database evidence changed; regenerate and review the plan"
      end
      validate_preflight!(plan, inventory, planner)
      @progress.start("baseline fingerprints and run checkpoint")
      run = @directory.join("runs", Time.now.utc.strftime("%Y%m%dT%H%M%S%6NZ"))
      run.mkpath
      File.chmod(0o700, run)
      state = {
        "status" => "applying",
        "mutation_started" => true,
        "run_dir" => run.to_s,
        "plan_sha256" => expected_sha256,
      }
      Artifacts.write(run.join("plan.json"), reviewed)
      Artifacts.write(run.join("restore-review.md"), <<~MARKDOWN, replace: false)
        # Restored site review

        Run `#{run.basename}` · Plan SHA-256 `#{expected_sha256}`

        Record the restored backup filename and checksum, review site, date, and tester here.

        | Check | Example and access state | Expected | Observed |
        | --- | --- | --- | --- |
        | Incoming original and thumbnail | | Both images load | Pending |
        | Retained destination download | | File opens | Pending |
        | Matched member profile | | Reviewed avatar displays | Pending |
        | Embedded photo and letter avatar | | Correct images on saved post and in editor preview | Pending |
        | Matched member Summary | | Visits and reading totals agree with activity and recorded exceptions | Pending |
        | Restricted topic as allowed member | | Content visible | Pending |
        | Same topic signed out | | Content hidden | Pending |
      MARKDOWN
      Configuration.write(run.join("baseline.json"), fingerprints)
      Configuration.write(run.join("source-baseline.json"), source_fingerprints(source_connection))
      @progress.start("archiving reviewed mapping inputs")
      archive_mapping_inputs!(plan, run)
      if plan.dig("upload_policy", "mode") == "preuploaded"
        path = run.join(PreparedUploads::FILE)
        File.open(path, "wb", 0o600) do |out|
          IO.copy_stream(PreparedUploads.path_for(@configuration).to_s, out)
        end
        unless Digest::SHA256.file(path).hexdigest == plan.dig("upload_policy", "receipt_sha256")
          raise Error, "Prepared uploads changed; regenerate and review the plan"
        end
      end
      @progress.start("final service check and run checkpoint")
      Environment.check!
      ensure_reviewed_inputs!(plan)
      begin
        write_state(run, state)
        @progress.recovery_run = run
        @progress.say("Run evidence: #{run}")
        require_relative "support"
        @progress.start("importer initialization")
        importer =
          Merger.new(
            plan: Plan.new(plan),
            run_dir: run,
            configuration: @configuration,
            source_connection: source_connection,
            destination_connection: destination_connection,
            progress: @progress,
          )
        @progress.start("pausing background jobs")
        Sidekiq.pause!("Discourse merge")
        if plan.dig("upload_policy", "mode") == "preuploaded" && !plan.dig("upload_policy", "preserve_destination_uploads")
          PreuploadedMedia.open(plan, run) do |media|
            media.update_destination!
            Configuration.write(run.join("prepared-baseline.json"), fingerprints)
          end
        end
        importer.start
        verify_run!(source_connection, Plan.new(plan), run, plan_sha256: expected_sha256)
        state["status"] = "verified"
      rescue Exception => error
        state["status"] = "failed"
        state["error"] = error.message
        state["last_stage"] = @progress.stage
        raise
      ensure
        write_state(run, state) if @directory.join("active-run.json").exist?
      end
      run
    ensure
      source_connection&.close
      destination_connection&.close
      lock&.close
    end

    def ensure_reviewed_inputs!(plan)
      raise Error, INPUT_CHANGED unless Planner.input_hashes(@directory) == plan["inputs_sha256"]
    rescue Errno::ENOENT, Errno::EISDIR
      raise Error, INPUT_CHANGED
    end

    def archive_mapping_inputs!(plan, run)
      expected = plan.fetch("inputs_sha256")
      paths = Planner.input_paths(@directory)
      raise Error, INPUT_CHANGED unless paths.keys.to_set == expected.keys.to_set
      archive = run.join("mapping-inputs")
      archive.mkdir(0o700)
      paths
        .except("merge.yml")
        .each do |name, path|
          bytes = path.binread
          digest = expected.fetch(name)
          raise Error, INPUT_CHANGED unless Digest::SHA256.hexdigest(bytes) == digest

          copy = archive.join(name)
          copy.dirname.mkdir(0o700) unless copy.dirname.directory?
          Artifacts.write(copy, bytes, replace: false)
          raise Error, INPUT_CHANGED unless Digest::SHA256.file(copy).hexdigest == digest
        end
    rescue Errno::ENOENT, Errno::EISDIR
      raise Error, INPUT_CHANGED
    end

    def preflight(setup_only: false, write_plan: false)
      scope = setup_only ? "setup" : "full"
      report_path = @directory.join(setup_only ? "preflight-setup.json" : "preflight.json")
      if !setup_only && @configuration.preuploaded?
        lock = File.open(@directory.join("workflow.lock"), "w", 0o600)
        unless lock.flock(File::LOCK_SH | File::LOCK_NB)
          raise Error, "Another workflow command is active"
        end
      end
      @progress.start("destination connection")
      destination = connect("destination")
      source = open_source(destination)
      validate_setup!(source, destination)
      report = {
        "status" => "ready",
        "scope" => scope,
        "source_database" => source.db,
        "destination_database" => destination.db,
        "upload_mode" => @configuration.upload_mode,
      }
      if setup_only
        report["sites"] = {
          "source" => source,
          "destination" => destination,
        }.transform_values { |connection| describe_site(connection) }
        report
          .fetch("sites")
          .each do |side, site|
            @progress.say(
              "#{side.capitalize} database #{site.fetch("database")}, site title #{site.fetch("title").inspect}, #{site.fetch("topics")} topics",
            )
          end
      else
        inventory = capture_inventory(source)
        @progress.start("mapping validation")
        planner = Planner.new(@configuration, inventory)
        @progress.say("Using mapping decisions from #{planner.mapping_input}")
        plan = planner.build
        report["coverage"] = plan.fetch("coverage", {})
        report["content"] = ContentPolicy.summary(plan.fetch("content", {}))
        validate_preflight!(plan, inventory, planner)
        planner.write(plan) if write_plan
        report.merge!(
          "inventory_sha256" => plan.fetch("inventory_sha256"),
          "file_bytes_verified" => !@configuration.preserve_remote?,
          "omitted_records" => inventory.dig("source", "pending_entities"),
        )
      end
      Configuration.write(report_path, report)
      @progress.say("Preflight ready (#{scope}): #{report_path}")
      write_plan ? plan : report
    rescue StandardError, LoadError, Interrupt => error
      Configuration.write(
        report_path,
        {
          "status" => "blocked",
          "scope" => scope,
          "stage" => @progress.stage,
          "blocker" => error.message,
          **(report || {}).slice("coverage", "content"),
        },
      )
      raise
    ensure
      source&.close
      destination&.close
      lock&.close
    end

    def capture_inventory(source)
      require_relative "merger"
      inventory =
        Inventory.new(@configuration, progress: @progress).capture(
          source_connection: source,
          content: true,
        )
      destination = inventory.fetch("destination")
      destination["login_required"] = SiteSetting.login_required
      destination.fetch("content")["settings"] = ContentInventory.destination_settings
      inventory
    end

    def describe_site(connection)
      row = connection.exec(<<~SQL).first
          SELECT (SELECT value FROM site_settings WHERE name = 'title') AS title,
                 (SELECT count(*) FROM topics) AS topics
        SQL
      {
        "database" => connection.db,
        "title" => row.fetch("title") || "Discourse",
        "topics" => Integer(row.fetch("topics")),
      }
    end

    def validate_setup!(source, destination)
      @progress.start("database migration history")
      versions =
        { "source" => source, "destination" => destination }.transform_values do |connection|
          connection.exec("SELECT version FROM schema_migrations ORDER BY version").column_values(0)
        rescue PG::UndefinedTable
          raise Error,
                "Database #{connection.db} has no migration history; restore or migrate its preparation environment"
        rescue PG::Error => error
          raise Error,
                "Cannot read migrations in #{connection.db}; check the configured database and role: #{error.message.strip}"
        end
      @progress.start("Rails destination identity and installed migrations")
      require_relative "../../../config/environment"
      Connections.verify_destination!(destination, ActiveRecord::Base.connection.raw_connection)
      required =
        ActiveRecord::Base.connection_pool.migration_context.migrations.map do |migration|
          migration.version.to_s
        end
      versions.each do |side, applied|
        missing = required - applied
        unless missing.empty?
          raise Error,
                "#{side} needs core/plugin migrations: #{missing.join(", ")}; migrate its preparation environment (including post migrations)"
        end
      end
      unless versions.fetch("source").last == versions.fetch("destination").last
        raise Error,
              "Latest migrations differ (source #{versions.fetch("source").last}, destination #{versions.fetch("destination").last}). Restore both backups using the same Discourse image and plugins."
      end
      @progress.start("destination services")
      Environment.check!
      @progress.start("destination backup, email, and upload settings")
      if BackupRestore.is_operation_running?
        raise Error, "Wait for the active backup or restore operation to finish"
      end
      unless SiteSetting.disable_emails == "yes"
        raise Error, "Set DISCOURSE_DISABLE_EMAILS=yes for the destination merger process"
      end
      return unless @configuration.upload_mode == "copy"
      raise Error, "Local upload storage is required in copy mode" if Discourse.store.external?
      source_root = Pathname.new(@configuration.data.fetch("source_upload_root"))
      unless source_root.directory? && source_root.readable? && source_root.executable?
        raise Error, "Source upload root is missing or unreadable: #{source_root}"
      end
      root = Pathname.new(@configuration.data.fetch("destination_upload_root"))
      store = Rails.public_path.join("uploads/default")
      unless root.directory? && store.directory? && root.realpath == store.realpath &&
               root.writable? && root.executable?
        raise Error,
              "Set destination_upload_root to the application's writable local upload directory (#{store})"
      end
    end

    # Shared by full preflight and apply, before the mutation marker.
    def validate_preflight!(plan, inventory, planner)
      @progress.start("schema, plugin, and upload validation")
      require_relative "merger"
      unsupported =
        inventory.fetch("source").fetch("unsupported_entities", {}).select { |_, count| count > 0 }
      raise Error, "Populated entities need an adapter: #{unsupported}" unless unsupported.empty?
      verify_source_files(plan, inventory)
      if inventory.dig("source", "solved")&.values&.any?(&:any?)
        # Earlier Solved versions dual-write both representations through SQL
        # triggers. Those triggers would duplicate explicit COPY IDs.
        %w[source destination].each do |side|
          if inventory.fetch(side).fetch("migrations").exclude?("20260408214007")
            raise Error, "#{side} needs Solved post migration 20260408214007 before import"
          end
        end
      end
      source_columns = inventory.dig("source", "columns")
      source_tables = source_columns.map { |column| column.fetch("table_name") }.to_set
      destination_columns =
        inventory
          .dig("destination", "columns")
          .select { |column| source_tables.include?(column.fetch("table_name")) }
      missing_columns = destination_columns - source_columns
      if missing_columns.any?
        columns =
          missing_columns
            .first(10)
            .map { |column| column.values_at("table_name", "column_name").join(".") }
        raise Error,
              "Source is missing compatible columns required by the destination: #{columns.join(", ")}. Restore the source using the same Discourse image and plugins as the destination."
      end
      required_models = Merger::REQUIRED_MODELS.dup
      if inventory.dig("source", "solved")&.values&.any?(&:any?)
        required_models += %w[
          DiscourseSolved::SolvedTopic
          DiscourseSolved::TopicAnswer
          DiscourseSolved::SharedIssue
        ]
      end
      required_tables =
        required_models.map do |name|
          (name.safe_constantize || raise(Error, "Missing importer model #{name}")).table_name
        end
      missing = required_tables.to_set - source_tables
      unless missing.empty?
        raise Error, "Source is missing importer tables: #{missing.to_a.join(", ")}"
      end
      solved_columns =
        source_columns
          .select { |column| column.fetch("table_name") == "discourse_solved_topic_answers" }
          .map { |column| column.fetch("column_name") }
      if inventory.dig("source", "solved", "discourse_solved_solved_topics")&.any? &&
           (%w[solved_topic_id answer_post_id accepter_user_id] - solved_columns).any?
        raise Error, "Solved data needs the compatible multiple-answer migrations before import"
      end
      @progress.start("destination mapping and namespace checks")
      plan
        .fetch("groups", [])
        .select { |group| group.fetch("action") == "copy" }
        .each do |group|
          candidate = Group.new(name: group.fetch("name"))
          unless candidate.valid? && candidate.name == group.fetch("name")
            raise Error,
                  "#{planner.group_location(group.fetch("source_group_id"))}: invalid planned group #{group.fetch("name")}: #{candidate.errors.full_messages.join(", ")}"
          end
        end
      maximum_depth = SiteSetting.max_category_nesting
      too_deep =
        plan
          .fetch("categories")
          .find do |category|
            category["operation"] != "preserve_existing" &&
              category.fetch("path").length > maximum_depth
          end
      if too_deep
        raise Error,
              "#{planner.category_location(too_deep.fetch("key"))}: #{too_deep.fetch("path").join(" > ")} exceeds the destination's max_category_nesting of #{maximum_depth}"
      end
      namespace_field = "#{@configuration.namespace}_import_id"
      if UserCustomField.where(name: namespace_field).exists? ||
           TopicCustomField.where(name: namespace_field).exists?
        raise Error, "This source namespace has already been imported into the destination"
      end
    end

    def connect(side, **options)
      require "pg"
      PG.connect(**{ connect_timeout: 5 }.merge(@configuration.connection(side)).merge(options))
    rescue PG::Error => error
      raise Error,
            "Cannot connect to the #{side} PostgreSQL database; check merge.yml, routing, and authentication: #{error.message.strip}"
    end

    def open_source(destination)
      @progress.start("source connection and database identity")
      connection = connect("source", options: "-c default_transaction_read_only=on")
      if connection.exec(Connections::IDENTITY_SQL).values ==
           destination.exec(Connections::IDENTITY_SQL).values
        raise Error,
              "Source and destination resolve to the same database; set separate restored databases in merge.yml"
      end
      connection.exec("BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY")
      unless connection.exec("SHOW default_transaction_read_only").getvalue(0, 0) == "on"
        raise Error, "Source connection is writable"
      end
      connection
    rescue Exception
      connection&.close
      raise
    end

    def verify_source_files(plan, inventory)
      if plan.dig("upload_policy", "mode") == "preuploaded"
        if %w[source destination].any? { |side|
             inventory.fetch(side).fetch("uploads").any? { |row| row["secure"] == "t" }
           } && !SiteSetting.secure_uploads?
          raise Error,
                "Protected uploads require secure_uploads on the hosted destination and merge environment"
        end
        return
      end
      return if @configuration.preserve_remote?
      root = Pathname.new(plan.dig("upload_policy", "source_upload_root")).realpath
      allowed = plan.dig("upload_policy", "source_hash_discrepancy_ids")
      inventory
        .dig("source", "uploads")
        .each do |upload|
          next if upload.fetch("id").to_i < 0
          relative = upload.fetch("url").delete_prefix("/uploads/default/")
          unless upload.fetch("url").start_with?("/uploads/default/")
            raise Error, "Source originals must have local /uploads/default paths"
          end
          file = Artifacts.upload_path(root, relative)
          unless file.size == upload.fetch("filesize").to_i
            raise Error, "Wrong upload size: #{upload["id"]}"
          end
          if Digest::SHA1.file(file).hexdigest != upload.fetch("sha1") &&
               !allowed.include?(upload.fetch("id").to_i)
            raise Error,
                  "Upload #{upload["id"]} differs from its recorded hash; investigate before accepting an exception"
          end
        end
    end

    def source_fingerprints(connection = nil)
      unless connection
        snapshot = connect("source", options: "-c default_transaction_read_only=on")
        snapshot.exec("BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY")
        connection = snapshot
      end
      connection
        .exec("SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename")
        .to_h do |row|
          table = PG::Connection.quote_ident(row.fetch("tablename"))
          result =
            connection
              .exec(
                "SELECT count(*)::text, coalesce(sum(('x' || substr(md5(to_jsonb(t)::text),1,16))::bit(64)::bigint::numeric),0)::text FROM #{table} t",
              )
              .values
              .first
          [row.fetch("tablename"), result]
        end
    ensure
      snapshot&.close
    end

    def write_state(run, state)
      Configuration.write(run.join("state.json"), state)
      Configuration.write(@directory.join("active-run.json"), state)
    end

    def fingerprints(baseline = nil, adopted_avatar_ids: [])
      tables = %w[users user_profiles user_options topics posts uploads] + ContentPolicy::TABLES
      tables += %w[optimized_images upload_references] if @configuration.preserve_destination_uploads?
      tables &= baseline.keys if baseline
      tables.to_h do |table|
        column = %w[user_profiles user_options].include?(table) ? "user_id" : "id"
        maximum =
          (
            if baseline
              baseline.fetch(table).fetch("maximum")
            else
              DB.query_single("SELECT coalesce(max(#{column}),0) FROM #{table}").first
            end
          )
        row = "to_jsonb(t)"
        if table == "users" && adopted_avatar_ids.any?
          reviewed_ids = adopted_avatar_ids.map { |id| Integer(id) }.join(",")
          row =
            "CASE WHEN t.id IN (#{reviewed_ids}) THEN jsonb_set(to_jsonb(t), '{uploaded_avatar_id}', 'null'::jsonb) ELSE to_jsonb(t) END"
        end
        result =
          DB.query(
            "SELECT count(*) AS row_count, coalesce(sum(('x' || substr(md5((#{row})::text),1,16))::bit(64)::bigint::numeric),0)::text AS fingerprint FROM #{table} t WHERE #{column} <= :maximum",
            maximum: maximum,
          ).first
        [table, { "maximum" => maximum, "count" => result.row_count, "hash" => result.fingerprint }]
      end
    end

    def verify
      @progress.start("completed run and frozen plan")
      unless @directory.join("active-run.json").file?
        raise Error, "No run found in #{@directory}; verify follows a successful apply"
      end
      state = JSON.parse(@directory.join("active-run.json").read)
      unless state["status"] == "verified"
        @progress.recovery_run = state["run_dir"]
        raise Error, "Only a completed run can be independently verified"
      end
      run = Pathname.new(state.fetch("run_dir"))
      reviewed = run.join("plan.json").binread
      unless Digest::SHA256.hexdigest(reviewed) == state.fetch("plan_sha256")
        raise Error, "Frozen run plan changed; restore the original evidence before verification"
      end
      @progress.start("Rails destination identity")
      require_relative "merger"
      plan = Plan.new(JSON.parse(reviewed))
      begin
        destination = connect("destination")
        Connections.verify_destination!(destination, ActiveRecord::Base.connection.raw_connection)
        connection = open_source(destination)
        @progress.start("destination services and email")
        Environment.check!
        unless SiteSetting.disable_emails == "yes"
          raise Error, "Set DISCOURSE_DISABLE_EMAILS=yes for the destination merger process"
        end
        @progress.recovery_run = run
        verify_run!(connection, plan, run, plan_sha256: state.fetch("plan_sha256"))
        run
      ensure
        destination&.close
        connection&.close
      end
    end

    def verify_run!(source, plan, run, plan_sha256:)
      @progress.start("import verification")
      ledger = run.join("ledger.json").binread
      importer = VerificationContext.new(source, JSON.parse(ledger))
      evidence = { "plan.json" => plan_sha256, "ledger.json" => Digest::SHA256.hexdigest(ledger) }
      Verifier
        .new(importer, plan, run, progress: @progress)
        .run!(evidence_sha256: evidence) do |verifier|
          @progress.start("source and destination fingerprint verification")
          baseline_file =
            (
              if plan.data.dig("upload_policy", "mode") == "preuploaded" && !plan.data.dig("upload_policy", "preserve_destination_uploads")
                "prepared-baseline.json"
              else
                "baseline.json"
              end
            )
          baseline = JSON.parse(run.join(baseline_file).read)
          verifier.check("existing_destination_records_preserved") do
            adopted =
              plan
                .data
                .fetch("matched_avatars", [])
                .filter_map do |decision|
                  decision.fetch("destination_user_id") if decision.fetch("choice") == "source"
                end
            fingerprints(baseline, adopted_avatar_ids: adopted) == baseline
          end
          source_baseline = JSON.parse(run.join("source-baseline.json").read)
          verifier.check("source_records_unchanged") { source_fingerprints == source_baseline }
        end
    end
  end
end

module BulkImport::DiscourseMerge
  module Connections
    IDENTITY_SQL =
      "SELECT extract(epoch from pg_postmaster_start_time())::text, current_database(), (SELECT oid::text FROM pg_database WHERE datname=current_database())"

    def self.verify_destination!(connection, rails_connection)
      unless connection.exec(IDENTITY_SQL).values == rails_connection.exec(IDENTITY_SQL).values
        raise Error,
              "Rails and merge.yml refer to different databases or servers for the destination; check DISCOURSE_DB_NAME, DISCOURSE_DB_HOST, and DISCOURSE_DB_PORT"
      end
    end

    def self.lock!(connection)
      unless connection.exec(
               "SELECT pg_try_advisory_lock(hashtext('discourse_merge'), 1)",
             ).getvalue(0, 0) == "t"
        raise Error, "Another importer holds the destination lock"
      end
    end
  end
end

module BulkImport::DiscourseMerge
  module Environment
    WORKERS = %w[unicorn pitchfork sidekiq].freeze

    def self.workers_running?(processes)
      processes.lines.any? do |line|
        executable, arguments = line.strip.split(/\s+/, 2)
        next false unless executable
        next true if WORKERS.include?(File.basename(executable))
        next false unless File.basename(executable).match?(/\A(?:ruby(?:\d+(?:\.\d+)*)?|bundle)\z/)
        arguments.to_s.match?(%r{(?:\A|[\s/])(?:unicorn|pitchfork|sidekiq)(?:[:\s]|\z)})
      end
    end

    def self.check!
      processes, process_status = Open3.capture2("ps", "-eo", "comm=,args=")
      unless process_status.success?
        raise Error,
              "Cannot list destination processes; run inside the destination container with ps available"
      end
      if workers_running?(processes)
        raise Error,
              "Destination web or workers are running; stop Unicorn or Pitchfork and Sidekiq as the container operator"
      end
      services =
        WORKERS.map { |name| "/etc/service/#{name}" }.select { |path| File.directory?(path) }
      if services.empty?
        raise Error,
              "No supervised Discourse services found under /etc/service; run as the application user inside the destination Discourse Docker container"
      end
      services.each do |service|
        status, diagnostic, result = Open3.capture3("sv", "status", service)
        if result.success? && status.start_with?("run:")
          raise Error,
                "Destination service is running; stop it as the container operator with sv stop #{service}"
        end
        unless result.success? && status.start_with?("down:")
          details = [status.strip, diagnostic.strip].reject(&:empty?).join(" ")
          raise Error,
                "Cannot read stopped status for #{service} as the merger user (#{details}). See “Bring your own environment” in script/bulk_import/discourse_merger/MERGE-DOCKER.md for the required supervise permissions."
        end
      end
      true
    rescue SystemCallError => error
      raise Error,
            "Cannot check destination services; verify ps and sv as the merger user: #{error.message}"
    end
  end
end
