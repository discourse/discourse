require_dependency "db_helper"

module BackupRestore

  class RestoreDisabledError < RuntimeError; end
  class FilenameMissingError < RuntimeError; end

  class Restorer
    attr_reader :success

    def self.pg_produces_portable_dump?(version)
      version = Gem::Version.new(version)

      %w{
        10.3
        9.6.8
        9.5.12
        9.4.17
        9.3.22
      }.each do |unportable_version|
        return false if Gem::Dependency.new("", "~> #{unportable_version}").match?("", version)
      end

      true
    end

    def initialize(user_id, opts = {})
      @user_id = user_id
      @client_id = opts[:client_id]
      @filename = opts[:filename]
      @publish_to_message_bus = opts[:publish_to_message_bus] || false

      ensure_restore_is_enabled
      ensure_no_operation_is_running
      ensure_we_have_a_user
      ensure_we_have_a_filename

      initialize_state
    end

    def run
      log "[STARTED]"
      log "'#{@user_info[:username]}' has started the restore!"

      mark_restore_as_running

      listen_for_shutdown_signal

      ensure_directory_exists(@tmp_directory)

      copy_archive_to_tmp_directory
      unzip_archive

      extract_metadata
      validate_metadata

      extract_dump

      if !can_restore_into_different_schema?
        log "Cannot restore into different schema, restoring in-place"
        enable_readonly_mode
        pause_sidekiq
        wait_for_sidekiq
        BackupRestore.move_tables_between_schemas("public", "backup")
        @db_was_changed = true
        restore_dump
      else
        log "Restoring into 'backup' schema"
        restore_dump
        enable_readonly_mode
        pause_sidekiq
        wait_for_sidekiq
        switch_schema!
      end

      migrate_database
      reconnect_database
      reload_site_settings
      clear_emoji_cache
      disable_readonly_mode
      clear_theme_cache

      extract_uploads
    rescue SystemExit
      log "Restore process was cancelled!"
      rollback
    rescue => ex
      log "EXCEPTION: " + ex.message
      log ex.backtrace.join("\n")
      rollback
    else
      @success = true
    ensure
      clean_up
      notify_user
      log "Finished!"

      @success ? log("[SUCCESS]") : log("[FAILED]")
    end

    protected

    def ensure_restore_is_enabled
      raise BackupRestore::RestoreDisabledError unless Rails.env.development? || SiteSetting.allow_restore?
    end

    def ensure_no_operation_is_running
      raise BackupRestore::OperationRunningError if BackupRestore.is_operation_running?
    end

    def ensure_we_have_a_user
      user = User.find_by(id: @user_id)
      raise Discourse::InvalidParameters.new(:user_id) unless user
      # keep some user data around to check them against the newly restored database
      @user_info = { id: user.id, username: user.username, email: user.email }
    end

    def ensure_we_have_a_filename
      raise BackupRestore::FilenameMissingError if @filename.nil?
    end

    def initialize_state
      @success = false
      @store = BackupRestore::BackupStore.create
      @db_was_changed = false
      @current_db = RailsMultisite::ConnectionManagement.current_db
      @current_version = BackupRestore.current_version
      @timestamp = Time.now.strftime("%Y-%m-%d-%H%M%S")
      @tmp_directory = File.join(Rails.root, "tmp", "restores", @current_db, @timestamp)
      @archive_filename = File.join(@tmp_directory, @filename)
      @tar_filename = @archive_filename[0...-3]
      @meta_filename = File.join(@tmp_directory, BackupRestore::METADATA_FILE)
      @is_archive = !(@filename =~ /.sql.gz$/)

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

    def mark_restore_as_running
      log "Marking restore as running..."
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

    def copy_archive_to_tmp_directory
      if @store.remote?
        log "Downloading archive to tmp directory..."
        failure_message = "Failed to download archive to tmp directory."
      else
        log "Copying archive to tmp directory..."
        failure_message = "Failed to copy archive to tmp directory."
      end

      @store.download_file(@filename, @archive_filename, failure_message)
    end

    def unzip_archive
      return unless @is_archive

      log "Unzipping archive, this may take a while..."

      FileUtils.cd(@tmp_directory) do
        Discourse::Utils.execute_command('gzip', '--decompress', @archive_filename, failure_message: "Failed to unzip archive.")
      end
    end

    def extract_metadata
      @metadata =
        if system('tar', '--list', '--file', @tar_filename, BackupRestore::METADATA_FILE)
          log "Extracting metadata file..."
          FileUtils.cd(@tmp_directory) do
            Discourse::Utils.execute_command(
              'tar', '--extract', '--file', @tar_filename, BackupRestore::METADATA_FILE,
              failure_message: "Failed to extract metadata file."
            )
          end

          data = Oj.load_file(@meta_filename)
          raise "Failed to load metadata file." if !data
          data
        else
          log "No metadata file to extract."
          if @filename =~ /-#{BackupRestore::VERSION_PREFIX}(\d{14})/
            { "version" => Regexp.last_match[1].to_i }
          else
            raise "Migration version is missing from the filename."
          end
        end
    end

    def validate_metadata
      log "Validating metadata..."
      log "  Current version: #{@current_version}"

      raise "Metadata has not been extracted correctly." if !@metadata

      log "  Restored version: #{@metadata["version"]}"

      error = "You're trying to restore a more recent version of the schema. You should migrate first!"
      raise error if @metadata["version"] > @current_version
    end

    def extract_dump
      @dump_filename =
        if @is_archive
          # For backwards compatibility
          if system('tar', '--list', '--file', @tar_filename, BackupRestore::OLD_DUMP_FILE)
            File.join(@tmp_directory, BackupRestore::OLD_DUMP_FILE)
          else
            File.join(@tmp_directory, BackupRestore::DUMP_FILE)
          end
        else
          File.join(@tmp_directory, @filename)
        end

      return unless @is_archive

      log "Extracting dump file..."

      FileUtils.cd(@tmp_directory) do
        Discourse::Utils.execute_command(
          'tar', '--extract', '--file', @tar_filename, File.basename(@dump_filename),
          failure_message: "Failed to extract dump file."
        )
      end
    end

    def get_dumped_by_version
      output = Discourse::Utils.execute_command(
        File.extname(@dump_filename) == '.gz' ? 'zgrep' : 'grep',
        '-m1', @dump_filename, '-e', "-- Dumped by pg_dump version",
        failure_message: "Failed to check version of pg_dump used to generate the dump file"
      )

      output.match(/version (\d+(\.\d+)+)/)[1]
    end

    def can_restore_into_different_schema?
      self.class.pg_produces_portable_dump?(get_dumped_by_version)
    end

    def restore_dump_command
      if File.extname(@dump_filename) == '.gz'
        "gzip -d < #{@dump_filename} | #{sed_command} | #{psql_command} 2>&1"
      else
        "#{psql_command} 2>&1 < #{@dump_filename}"
      end
    end

    def restore_dump
      log "Restoring dump file... (can be quite long)"

      logs = Queue.new
      psql_running = true
      has_error = false

      Thread.new do
        RailsMultisite::ConnectionManagement::establish_connection(db: @current_db)
        while psql_running
          message = logs.pop.strip
          has_error ||= (message =~ /ERROR:/)
          log(message) unless message.blank?
        end
      end

      IO.popen(restore_dump_command) do |pipe|
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

    def psql_command
      db_conf = BackupRestore.database_configuration

      password_argument = "PGPASSWORD='#{db_conf.password}'" if db_conf.password.present?
      host_argument     = "--host=#{db_conf.host}"         if db_conf.host.present?
      port_argument     = "--port=#{db_conf.port}"         if db_conf.port.present?
      username_argument = "--username=#{db_conf.username}" if db_conf.username.present?

      [ password_argument,                # pass the password to psql (if any)
        "psql",                           # the psql command
        "--dbname='#{db_conf.database}'", # connect to database *dbname*
        "--single-transaction",           # all or nothing (also runs COPY commands faster)
        host_argument,                    # the hostname to connect to (if any)
        port_argument,                    # the port to connect to (if any)
        username_argument                 # the username to connect as (if any)
      ].join(" ")
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

      "sed -e '#{expression}'"
    end

    def switch_schema!
      log "Switching schemas... try reloading the site in 5 minutes, if successful, then reboot and restore is complete."

      sql = [
        "BEGIN;",
        BackupRestore.move_tables_between_schemas_sql("public", "backup"),
        BackupRestore.move_tables_between_schemas_sql("restore", "public"),
        "COMMIT;"
      ].join("\n")

      @db_was_changed = true

      DB.exec(sql)
    end

    def migrate_database
      log "Migrating the database..."
      Discourse::Application.load_tasks
      ENV["VERSION"] = @current_version.to_s
      DB.exec("SET search_path = public, pg_catalog;")
      Rake::Task["db:migrate"].invoke
    end

    def reconnect_database
      log "Reconnecting to the database..."
      RailsMultisite::ConnectionManagement::establish_connection(db: @current_db)
    end

    def reload_site_settings
      log "Reloading site settings..."
      SiteSetting.refresh!
    end

    def clear_emoji_cache
      log "Clearing emoji cache..."
      Emoji.clear_cache
    end

    def extract_uploads
      if system('tar', '--exclude=*/*', '--list', '--file', @tar_filename, 'uploads')
        log "Extracting uploads..."

        FileUtils.cd(@tmp_directory) do
          Discourse::Utils.execute_command(
            'tar', '--extract', '--keep-newer-files', '--file', @tar_filename, 'uploads/',
            failure_message: "Failed to extract uploads."
          )
        end

        public_uploads_path = File.join(Rails.root, "public")

        FileUtils.cd(public_uploads_path) do
          FileUtils.mkdir_p("uploads")

          tmp_uploads_path = Dir.glob(File.join(@tmp_directory, "uploads", "*")).first
          previous_db_name = File.basename(tmp_uploads_path)
          current_db_name = RailsMultisite::ConnectionManagement.current_db

          Discourse::Utils.execute_command(
            'rsync', '-avp', '--safe-links', "#{tmp_uploads_path}/", "uploads/#{current_db_name}/",
            failure_message: "Failed to restore uploads."
          )

          if previous_db_name != current_db_name
            DbHelper.remap("uploads/#{previous_db_name}", "uploads/#{current_db_name}")
          end
        end
      end
    end

    def rollback
      log "Trying to rollback..."
      if @db_was_changed && BackupRestore.can_rollback?
        log "Rolling back..."
        BackupRestore.move_tables_between_schemas("backup", "public")
      else
        log "There was no need to rollback"
      end
    end

    def notify_user
      if user = User.find_by_email(@user_info[:email])
        log "Notifying '#{user.username}' of the end of the restore..."
        status = @success ? :restore_succeeded : :restore_failed

        SystemMessage.create_from_system_user(user, status,
          logs: Discourse::Utils.pretty_logs(@logs)
        )
      else
        log "Could not send notification to '#{@user_info[:username]}' (#{@user_info[:email]}), because the user does not exists..."
      end
    rescue => ex
      log "Something went wrong while notifying user.", ex
    end

    def clean_up
      log "Cleaning stuff up..."
      remove_tmp_directory
      unpause_sidekiq
      disable_readonly_mode if Discourse.readonly_mode?
      mark_restore_as_not_running
    end

    def remove_tmp_directory
      log "Removing tmp '#{@tmp_directory}' directory..."
      FileUtils.rm_rf(@tmp_directory) if Dir[@tmp_directory].present?
    rescue => ex
      log "Something went wrong while removing the following tmp directory: #{@tmp_directory}", ex
    end

    def unpause_sidekiq
      log "Unpausing sidekiq..."
      Sidekiq.unpause!
    rescue => ex
      log "Something went wrong while unpausing Sidekiq.", ex
    end

    def clear_theme_cache
      log "Clear theme cache"
      ThemeField.force_recompilation!
      Theme.expire_site_cache!
    end

    def disable_readonly_mode
      return if @readonly_mode_was_enabled
      log "Disabling readonly mode..."
      Discourse.disable_readonly_mode
    rescue => ex
      log "Something went wrong while disabling readonly mode.", ex
    end

    def mark_restore_as_not_running
      log "Marking restore as finished..."
      BackupRestore.mark_as_not_running!
    rescue => ex
      log "Something went wrong while marking restore as finished.", ex
    end

    def ensure_directory_exists(directory)
      log "Making sure #{directory} exists..."
      FileUtils.mkdir_p(directory)
    end

    def log(message, ex = nil)
      timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
      puts(message)
      publish_log(message, timestamp)
      save_log(message, timestamp)
      Rails.logger.error("#{ex}\n" + ex.backtrace.join("\n")) if ex
    end

    def publish_log(message, timestamp)
      return unless @publish_to_message_bus
      data = { timestamp: timestamp, operation: "restore", message: message }
      MessageBus.publish(BackupRestore::LOGS_CHANNEL, data, user_ids: [@user_id], client_ids: [@client_id])
    end

    def save_log(message, timestamp)
      @logs << "[#{timestamp}] #{message}"
    end

  end

end
