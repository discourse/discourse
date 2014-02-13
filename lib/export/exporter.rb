module Export

  class Exporter

    def initialize(user_id, publish_to_message_bus = false)
      @user_id, @publish_to_message_bus = user_id, publish_to_message_bus

      ensure_no_operation_is_running
      ensure_we_have_a_user

      initialize_state
    end

    def run
      log "[STARTED]"
      log "'#{@user.username}' has started the backup!"

      mark_export_as_running

      listen_for_shutdown_signal

      enable_readonly_mode

      pause_sidekiq
      wait_for_sidekiq

      ensure_directory_exists(@tmp_directory)

      write_metadata

      dump_public_schema

      update_dump

      log "Finalizing backup..."

      ensure_directory_exists(@archive_directory)

      create_archive

      notify_user
    rescue SystemExit
      log "Backup process was cancelled!"
    rescue Exception => ex
      log "EXCEPTION: " + ex.message
      log ex.backtrace.join("\n")
    else
      @success = true
      "#{@archive_basename}.tar.gz"
    ensure
      clean_up
      @success ? log("[SUCCESS]") : log("[FAILED]")
    end

    protected

    def ensure_no_operation_is_running
      raise BackupRestore::OperationRunningError if BackupRestore.is_operation_running?
    end

    def ensure_we_have_a_user
      @user = User.where(id: @user_id).first
      raise Discourse::InvalidParameters.new(:user_id) unless @user
    end

    def initialize_state
      @success = false
      @current_db = RailsMultisite::ConnectionManagement.current_db
      @timestamp = Time.now.strftime("%Y-%m-%d-%H%M%S")
      @tmp_directory = File.join(Rails.root, "tmp", "backups", @current_db, @timestamp)
      @dump_filename = File.join(@tmp_directory, BackupRestore::DUMP_FILE)
      @meta_filename = File.join(@tmp_directory, BackupRestore::METADATA_FILE)
      @archive_directory = File.join(Rails.root, "public", "backups", @current_db)
      @archive_basename = File.join(@archive_directory, @timestamp)
    end

    def listen_for_shutdown_signal
      Thread.new do
        while BackupRestore.is_operation_running?
          exit if BackupRestore.should_shutdown?
          sleep 0.1
        end
      end
    end

    def mark_export_as_running
      log "Marking backup as running..."
      BackupRestore.mark_as_running!
    end

    def enable_readonly_mode
      log "Enabling readonly mode..."
      Discourse.enable_readonly_mode
    end

    def pause_sidekiq
      log "Pausing sidekiq..."
      Sidekiq.pause!
    end

    def wait_for_sidekiq
      log "Waiting for sidekiq to finish running jobs..."
      iterations = 0
      while (running = Sidekiq::Queue.all.map(&:size).sum) > 0
        log "  Waiting for #{running} jobs..."
        sleep 2
        iterations += 1
        raise "Sidekiq did not finish running all the jobs in the allowed time!" if iterations >= 15
      end
    end

    def write_metadata
      log "Writing metadata to '#{@meta_filename}'..."
      metadata = {
        source: "discourse",
        version: BackupRestore.current_version
      }
      File.write(@meta_filename, metadata.to_json)
    end

    def dump_public_schema
      log "Dumping the public schema of the database..."

      pg_dump_command = build_pg_dump_command
      log "Running: #{pg_dump_command}"

      logs = Queue.new
      pg_dump_running = true

      Thread.new do
        while pg_dump_running
          message = logs.pop.strip
          log(message) unless message.blank?
        end
      end

      IO.popen("#{pg_dump_command} 2>&1") do |pipe|
        begin
          while line = pipe.readline
            logs << line
          end
        rescue EOFError
          # finished reading...
        ensure
          pg_dump_running = false
          logs << ""
        end
      end

      raise "pg_dump failed" unless $?.success?
    end

    def build_pg_dump_command
      db_conf = Rails.configuration.database_configuration[Rails.env]
      host = db_conf["host"] || "localhost"
      password = db_conf["password"]
      username = db_conf["username"] || "postgres"
      database = db_conf["database"]

      [ "PGPASSWORD=#{password}",           # pass the password to pg_dump
        "pg_dump",                          # the pg_dump command
        "--exclude-schema=backup,restore",  # exclude both backup & restore schemes
        "--file='#{@dump_filename}'",       # output to the dump.sql file
        "--no-owner",                       # do not output commands to set ownership of objects
        "--no-privileges",                  # prevent dumping of access privileges
        "--verbose",                        # specifies verbose mode
        "--host=#{host}",                   # the hostname to connect to
        "--username=#{username}",           # the username to connect as
        database                            # the name of the database to dump
      ].join(" ")
    end

    def update_dump
      log "Updating dump for more awesomeness..."

      sed_command = build_sed_command

      log "Running: #{sed_command}"

      `#{sed_command}`
    end

    def build_sed_command
      # in order to limit the downtime when restoring as much as possible
      # we force the restoration to happen in the "restore" schema

      # during the restoration, this make sure we
      #  - drop the "restore" schema if it exists
      #  - create the "restore" schema
      #  - prepend the "restore" schema into the search_path

      regexp = "^SET search_path = public, pg_catalog;$"

      replacement = [ "DROP SCHEMA IF EXISTS restore CASCADE;",
                      "CREATE SCHEMA restore;",
                      "SET search_path = restore, public, pg_catalog;",
                    ].join("\\n")

      # we only want to replace the VERY first occurence of the search_path command
      expression = "0,/#{regexp}/s//#{replacement}/"

      # I tried to use the --in-place argument but it was SLOOOWWWWwwwwww
      # so I output the result into another file and rename it back afterwards
      [ "sed --expression='#{expression}' < #{@dump_filename} > #{@dump_filename}.tmp",
        "&&",
        "mv #{@dump_filename}.tmp #{@dump_filename}",
      ].join(" ")
    end

    def create_archive
      log "Creating archive: #{File.basename(@archive_basename)}.tar.gz"

      tar_filename = "#{@archive_basename}.tar"

      log "Making sure archive does not already exist..."
      `rm -f #{tar_filename}`
      `rm -f #{tar_filename}.gz`

      log "Creating empty archive..."
      `tar --create --file #{tar_filename} --files-from /dev/null`

      log "Archiving metadata..."
      FileUtils.cd(File.dirname(@meta_filename)) do
        `tar --append --file #{tar_filename} #{File.basename(@meta_filename)}`
      end

      log "Archiving data dump..."
      FileUtils.cd(File.dirname(@dump_filename)) do
        `tar --append --file #{tar_filename} #{File.basename(@dump_filename)}`
      end

      upload_directory = "uploads/" + @current_db

      if Dir[upload_directory].present?

        log "Archiving uploads..."
        FileUtils.cd(File.join(Rails.root, "public")) do
          `tar --append --file #{tar_filename} #{upload_directory}`
        end

      end

      log "Gzipping archive..."
      `gzip #{tar_filename}`
    end

    def notify_user
      log "Notifying '#{@user.username}' of the success of the backup..."
      # NOTE: will only notify if @user != Discourse.site_contact_user
      SystemMessage.create(@user, :export_succeeded)
    end

    def clean_up
      log "Cleaning stuff up..."
      remove_tmp_directory
      unpause_sidekiq
      disable_readonly_mode
      mark_export_as_not_running
      log "Finished!"
    end

    def remove_tmp_directory
      log "Removing tmp '#{@tmp_directory}' directory..."
      FileUtils.rm_rf(@tmp_directory) if Dir[@tmp_directory].present?
    rescue
      log "Something went wrong while removing the following tmp directory: #{@tmp_directory}"
    end

    def unpause_sidekiq
      log "Unpausing sidekiq..."
      Sidekiq.unpause!
    end

    def disable_readonly_mode
      log "Disabling readonly mode..."
      Discourse.disable_readonly_mode
    end

    def mark_export_as_not_running
      log "Marking backup as finished..."
      BackupRestore.mark_as_not_running!
    end

    def ensure_directory_exists(directory)
      log "Making sure '#{directory}' exists..."
      FileUtils.mkdir_p(directory)
    end

    def log(message)
      puts(message) rescue nil
      publish_log(message) rescue nil
    end

    def publish_log(message)
      return unless @publish_to_message_bus
      data = { timestamp: Time.now, operation: "backup", message: message }
      MessageBus.publish("/admin/backups/logs", data, user_ids: [@user_id])
    end

  end

end
