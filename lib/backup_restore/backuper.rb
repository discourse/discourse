module BackupRestore

  class Backuper

    attr_reader :success

    def initialize(user_id, opts={})
      @user_id = user_id
      @client_id = opts[:client_id]
      @publish_to_message_bus = opts[:publish_to_message_bus] || false
      @with_uploads = opts[:with_uploads].nil? ? true : opts[:with_uploads]

      ensure_no_operation_is_running
      ensure_we_have_a_user

      initialize_state
    end

    def run
      log "[STARTED]"
      log "'#{@user.username}' has started the backup!"

      mark_backup_as_running

      listen_for_shutdown_signal

      ensure_directory_exists(@tmp_directory)
      ensure_directory_exists(@archive_directory)

      write_metadata

      ### READ-ONLY / START ###
      enable_readonly_mode

      pause_sidekiq
      wait_for_sidekiq

      dump_public_schema

      disable_readonly_mode
      ### READ-ONLY / END ###

      log "Finalizing backup..."

      update_dump

      create_archive

      after_create_hook
    rescue SystemExit
      log "Backup process was cancelled!"
    rescue Exception => ex
      log "EXCEPTION: " + ex.message
      log ex.backtrace.join("\n")
    else
      @success = true
      "#{@archive_basename}.tar.gz"
    ensure
      notify_user rescue nil
      remove_old rescue nil
      clean_up
      @success ? log("[SUCCESS]") : log("[FAILED]")
    end

    protected

    def ensure_no_operation_is_running
      raise BackupRestore::OperationRunningError if BackupRestore.is_operation_running?
    end

    def ensure_we_have_a_user
      @user = User.find_by(id: @user_id)
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
      @archive_basename = File.join(@archive_directory, "#{SiteSetting.title.parameterize}-#{@timestamp}")
      @logs = []
      @readonly_mode_was_enabled = Discourse.readonly_mode?
    end

    def listen_for_shutdown_signal
      Thread.new do
        while BackupRestore.is_operation_running?
          exit if BackupRestore.should_shutdown?
          sleep 0.1
        end
      end
    end

    def mark_backup_as_running
      log "Marking backup as running..."
      BackupRestore.mark_as_running!
    end

    def enable_readonly_mode
      return if @readonly_mode_was_enabled
      log "Enabling readonly mode..."
      Discourse.enable_readonly_mode
    end

    def pause_sidekiq
      log "Pausing sidekiq..."
      Sidekiq.pause!
    end

    def wait_for_sidekiq
      log "Waiting for sidekiq to finish running jobs..."
      iterations = 1
      while sidekiq_has_running_jobs?
        log "Waiting for sidekiq to finish running jobs... ##{iterations}"
        sleep 5
        iterations += 1
        raise "Sidekiq did not finish running all the jobs in the allowed time!" if iterations > 6
      end
    end

    def sidekiq_has_running_jobs?
      Sidekiq::Workers.new.each do |_, _, worker|
        payload = worker.try(:payload)
        return true if payload.try(:all_sites)
        return true if payload.try(:current_site_id) == @current_db
      end

      false
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

      logs = Queue.new
      pg_dump_running = true

      Thread.new do
        RailsMultisite::ConnectionManagement::establish_connection(db: @current_db)
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

    def pg_dump_command
      db_conf = BackupRestore.database_configuration

      password_argument = "PGPASSWORD='#{db_conf.password}'" if db_conf.password.present?
      host_argument     = "--host=#{db_conf.host}"         if db_conf.host.present?
      port_argument     = "--port=#{db_conf.port}"         if db_conf.port.present?
      username_argument = "--username=#{db_conf.username}" if db_conf.username.present?

      [ password_argument,            # pass the password to pg_dump (if any)
        "pg_dump",                    # the pg_dump command
        "--schema=public",            # only public schema
        "--file='#{@dump_filename}'", # output to the dump.sql file
        "--no-owner",                 # do not output commands to set ownership of objects
        "--no-privileges",            # prevent dumping of access privileges
        "--verbose",                  # specifies verbose mode
        host_argument,                # the hostname to connect to (if any)
        port_argument,                # the port to connect to (if any)
        username_argument,            # the username to connect as (if any)
        db_conf.database              # the name of the database to dump
      ].join(" ")
    end

    def update_dump
      log "Updating dump for more awesomeness..."

      `#{sed_command}`
    end

    def sed_command
      # in order to limit the downtime when restoring as much as possible
      # we force the restoration to happen in the "restore" schema

      # during the restoration, this make sure we
      #  - drop the "restore" schema if it exists
      #  - create the "restore" schema
      #  - prepend the "restore" schema into the search_path

      regexp = "SET search_path = public, pg_catalog;"

      replacement = [ "DROP SCHEMA IF EXISTS restore CASCADE;",
                      "CREATE SCHEMA restore;",
                      "SET search_path = restore, public, pg_catalog;",
                    ].join(" ")

      # we only want to replace the VERY first occurence of the search_path command
      expression = "1,/^#{regexp}$/s/#{regexp}/#{replacement}/"

      # I tried to use the --in-place argument but it was SLOOOWWWWwwwwww
      # so I output the result into another file and rename it back afterwards
      [ "sed -e '#{expression}' < #{@dump_filename} > #{@dump_filename}.tmp",
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
        `tar --append --dereference --file #{tar_filename} #{File.basename(@meta_filename)}`
      end

      log "Archiving data dump..."
      FileUtils.cd(File.dirname(@dump_filename)) do
        `tar --append --dereference --file #{tar_filename} #{File.basename(@dump_filename)}`
      end

      if @with_uploads
        upload_directory = "uploads/" + @current_db

        log "Archiving uploads..."
        FileUtils.cd(File.join(Rails.root, "public")) do
          `tar --append --dereference --file #{tar_filename} #{upload_directory}`
        end
      end

      log "Gzipping archive, this may take a while..."
      `gzip -5 #{tar_filename}`
    end

    def after_create_hook
      log "Executing the after_create_hook for the backup..."
      backup = Backup.create_from_filename("#{File.basename(@archive_basename)}.tar.gz")
      backup.after_create_hook
    end

    def remove_old
      log "Removing old backups..."
      Backup.remove_old
    end

    def notify_user
      log "Notifying '#{@user.username}' of the end of the backup..."
      if @success
        SystemMessage.create_from_system_user(@user, :backup_succeeded)
      else
        SystemMessage.create_from_system_user(@user, :backup_failed, logs: @logs.join("\n"))
      end
    end

    def clean_up
      log "Cleaning stuff up..."
      remove_tar_leftovers
      remove_tmp_directory
      unpause_sidekiq
      disable_readonly_mode if Discourse.readonly_mode?
      mark_backup_as_not_running
      log "Finished!"
    end

    def remove_tar_leftovers
      log "Removing '.tar' leftovers..."
      `rm -f #{@archive_directory}/*.tar`
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
    rescue
      log "Something went wrong while unpausing Sidekiq."
    end

    def disable_readonly_mode
      return if @readonly_mode_was_enabled
      log "Disabling readonly mode..."
      Discourse.disable_readonly_mode
    end

    def mark_backup_as_not_running
      log "Marking backup as finished..."
      BackupRestore.mark_as_not_running!
    end

    def ensure_directory_exists(directory)
      log "Making sure '#{directory}' exists..."
      FileUtils.mkdir_p(directory)
    end

    def log(message)
      timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
      puts(message) rescue nil
      publish_log(message, timestamp) rescue nil
      save_log(message, timestamp)
    end

    def publish_log(message, timestamp)
      return unless @publish_to_message_bus
      data = { timestamp: timestamp, operation: "backup", message: message }
      MessageBus.publish(BackupRestore::LOGS_CHANNEL, data, user_ids: [@user_id], client_ids: [@client_id])
    end

    def save_log(message, timestamp)
      @logs << "[#{timestamp}] #{message}"
    end

  end

end
