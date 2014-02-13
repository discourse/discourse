module Import

  class ImportDisabledError  < RuntimeError; end
  class FilenameMissingError < RuntimeError; end

  class Importer

    def initialize(user_id, filename, publish_to_message_bus = false)
      @user_id, @filename, @publish_to_message_bus = user_id, filename, publish_to_message_bus

      ensure_import_is_enabled
      ensure_no_operation_is_running
      ensure_we_have_a_user
      ensure_we_have_a_filename

      initialize_state
    end

    def run
      log "[STARTED]"
      log "'#{@user_info[:username]}' has started the restore!"

      mark_import_as_running

      listen_for_shutdown_signal

      enable_readonly_mode

      pause_sidekiq
      wait_for_sidekiq

      ensure_directory_exists(@tmp_directory)

      copy_archive_to_tmp_directory
      unzip_archive

      extract_metadata
      validate_metadata

      extract_dump

      restore_dump

      #----------- CRITICAL --------------
      switch_schema!
      #----------- CRITICAL --------------

      log "Finalizing restore..."

      migrate_database

      reconnect_database

      extract_uploads

      notify_user
    rescue SystemExit
      log "Restore process was cancelled!"
      rollback
    rescue Exception => ex
      log "EXCEPTION: " + ex.message
      log ex.backtrace.join("\n")
      rollback
    else
      @success = true
    ensure
      clean_up
      @success ? log("[SUCCESS]") : log("[FAILED]")
    end

    protected

    def ensure_import_is_enabled
      raise Import::ImportDisabledError unless SiteSetting.allow_import?
    end

    def ensure_no_operation_is_running
      raise BackupRestore::OperationRunningError if BackupRestore.is_operation_running?
    end

    def ensure_we_have_a_user
      user = User.where(id: @user_id).first
      raise Discourse::InvalidParameters.new(:user_id) unless user
      # keep some user data around to check them against the newly restored database
      @user_info = { id: user.id, username: user.username, email: user.email }
    end

    def ensure_we_have_a_filename
      raise Import::FilenameMissingError if @filename.nil?
    end

    def initialize_state
      @success = false
      @current_db = RailsMultisite::ConnectionManagement.current_db
      @current_version = BackupRestore.current_version
      @timestamp = Time.now.strftime("%Y-%m-%d-%H%M%S")
      @tmp_directory = File.join(Rails.root, "tmp", "restores", @current_db, @timestamp)
      @archive_filename = File.join(@tmp_directory, @filename)
      @tar_filename = @archive_filename[0...-3]
      @meta_filename = File.join(@tmp_directory, BackupRestore::METADATA_FILE)
      @dump_filename = File.join(@tmp_directory, BackupRestore::DUMP_FILE)
    end

    def listen_for_shutdown_signal
      Thread.new do
        while BackupRestore.is_operation_running?
          exit if BackupRestore.should_shutdown?
          sleep 0.1
        end
      end
    end

    def mark_import_as_running
      log "Marking restore as running..."
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
        sleep 5
        iterations += 1
        raise "Sidekiq did not finish running all the jobs in the allowed time!" if iterations >= 20
      end
    end

    def copy_archive_to_tmp_directory
      log "Copying archive to tmp directory..."
      source = File.join(Backup.base_directory, @filename)
      `cp #{source} #{@archive_filename}`
    end

    def unzip_archive
      log "Unzipping archive..."
      FileUtils.cd(@tmp_directory) { `gzip --decompress #{@archive_filename}` }
    end

    def extract_metadata
      log "Extracting metadata file..."
      FileUtils.cd(@tmp_directory) { `tar --extract --file #{@tar_filename} #{BackupRestore::METADATA_FILE}` }
      @metadata = Oj.load_file(@meta_filename)
    end

    def validate_metadata
      log "Validating metadata..."
      log "  Current version: #{@current_version}"
      log "  Restored version: #{@metadata["version"]}"

      error = "You're trying to import a more recent version of the schema. You should migrate first!"
      raise error if @metadata["version"] > @current_version
    end

    def extract_dump
      log "Extracting dump file..."
      FileUtils.cd(@tmp_directory) { `tar --extract --file #{@tar_filename} #{BackupRestore::DUMP_FILE}` }
    end

    def restore_dump
      log "Restoring dump file... (can be quite long)"

      psql_command = build_psql_command
      log "Running: #{psql_command}"

      logs = Queue.new
      psql_running = true
      has_error = false

      Thread.new do
        while psql_running
          message = logs.pop.strip
          has_error ||= (message =~ /ERROR:/)
          log(message) unless message.blank?
        end
      end

      IO.popen("#{psql_command} 2>&1") do |pipe|
        begin
          while line = pipe.readline
            logs << line
          end
        rescue EOFError
          # finished reading...
        ensure
          psql_running = false
          logs << ""
        end
      end

      # psql does not return a valid exit code when an error happens
      raise "psql failed" if has_error
    end

    def build_psql_command
      db_conf = Rails.configuration.database_configuration[Rails.env]
      host = db_conf["host"] || "localhost"
      password = db_conf["password"]
      username = db_conf["username"] || "postgres"
      database = db_conf["database"]

      [ "PGPASSWORD=#{password}",     # pass the password to psql
        "psql",                       # the psql command
        "--dbname='#{database}'",     # connect to database *dbname*
        "--file='#{@dump_filename}'", # read the dump
        "--single-transaction",       # all or nothing (also runs COPY commands faster)
        "--host=#{host}",             # the hostname to connect to
        "--username=#{username}"      # the username to connect as
      ].join(" ")
    end

    def switch_schema!
      log "Switching schemas..."

      sql = <<-SQL
        BEGIN;
          DROP SCHEMA IF EXISTS backup CASCADE;
          ALTER SCHEMA public RENAME TO backup;
          ALTER SCHEMA restore RENAME TO public;
        COMMIT;
      SQL

      User.exec_sql(sql)
    end

    def migrate_database
      log "Migrating the database..."
      Discourse::Application.load_tasks
      ENV["VERSION"] = @current_version.to_s
      Rake::Task["db:migrate:up"].invoke
    end

    def reconnect_database
      log "Reconnecting to the database..."
      ActiveRecord::Base.establish_connection
    end

    def extract_uploads
      log "Extracting uploads..."
      if `tar --list --file #{@tar_filename} | grep 'uploads/'`.present?
        FileUtils.cd(File.join(Rails.root, "public")) do
          `tar --extract --keep-newer-files --file #{@tar_filename} uploads/`
        end
      end
    end

    def notify_user
      if user = User.where(email: @user_info[:email]).first
        log "Notifying '#{user.username}' of the success of the restore..."
        # NOTE: will only notify if user != Discourse.site_contact_user
        SystemMessage.create(user, :import_succeeded)
      else
        log "Could not send notification to '#{@user_info[:username]}' (#{@user_info[:email]}), because the user does not exists..."
      end
    end

    def rollback
      log "Trying to rollback..."
      if BackupRestore.can_rollback?
        log "Rolling back to previous working state..."
        BackupRestore.rename_schema("backup", "public")
      else
        log "No backup schema was created yet!"
      end
    end

    def clean_up
      log "Cleaning stuff up..."
      remove_tmp_directory
      unpause_sidekiq
      disable_readonly_mode
      mark_import_as_not_running
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

    def mark_import_as_not_running
      log "Marking restore as finished..."
      BackupRestore.mark_as_not_running!
    end

    def ensure_directory_exists(directory)
      log "Making sure #{directory} exists..."
      FileUtils.mkdir_p(directory)
    end

    def log(message)
      puts(message) rescue nil
      publish_log(message) rescue nil
    end

    def publish_log(message)
      return unless @publish_to_message_bus
      data = { timestamp: Time.now, operation: "restore", message: message }
      MessageBus.publish("/admin/backups/logs", data, user_ids: [@user_id])
    end

  end

end
