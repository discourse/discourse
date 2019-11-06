# frozen_string_literal: true

require_dependency "db_helper"

module BackupRestore

  class RestoreDisabledError < RuntimeError; end
  class FilenameMissingError < RuntimeError; end

  class Restorer
    attr_reader :success

    def self.pg_produces_portable_dump?(version)
      # anything pg 11 or above will produce a non-portable dump
      return false if version.to_i >= 11

      # below 11, the behaviour was changed in multiple different minor
      # versions depending on major release line - we list those versions below
      gem_version = Gem::Version.new(version)

      %w{
        10.3
        9.6.8
        9.5.12
        9.4.17
        9.3.22
      }.each do |unportable_version|
        return false if Gem::Dependency.new("", "~> #{unportable_version}").match?("", gem_version)
      end

      true
    end

    def initialize(user_id, opts = {})
      @user_id = user_id
      @client_id = opts[:client_id]
      @filename = opts[:filename]
      @publish_to_message_bus = opts[:publish_to_message_bus] || false
      @disable_emails = opts.fetch(:disable_emails, true)

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
      decompress_archive

      extract_metadata
      validate_metadata

      extract_dump
      create_missing_discourse_functions

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

      after_restore_hook
    rescue Compression::Strategy::ExtractFailed
      log "The uncompressed file is too big. Consider increasing the decompressed_theme_max_file_size_mb hidden setting."
      rollback
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

    ### The methods listed below are public just for testing purposes.
    ### This is not a good practice, but we need to be sure that our new compression API will work.

    attr_reader :tmp_directory

    def ensure_directory_exists(directory)
      log "Making sure #{directory} exists..."
      FileUtils.mkdir_p(directory)
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

    def decompress_archive
      return unless @is_archive

      log "Unzipping archive, this may take a while..."

      pipeline = Compression::Pipeline.new([Compression::Tar.new, Compression::Gzip.new])

      unzipped_path = pipeline.decompress(@tmp_directory, @archive_filename, available_size)
      pipeline.strip_directory(unzipped_path, @tmp_directory)
    end

    def extract_metadata
      metadata_path = File.join(@tmp_directory, BackupRestore::METADATA_FILE)
      @metadata = if File.exists?(metadata_path)
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

    def extract_dump
      @dump_filename =
        if @is_archive
          # For backwards compatibility
          old_dump_path = File.join(@tmp_directory, BackupRestore::OLD_DUMP_FILE)
          File.exists?(old_dump_path) ? old_dump_path : File.join(@tmp_directory, BackupRestore::DUMP_FILE)
        else
          File.join(@tmp_directory, @filename)
        end

      log "Extracting dump file..."

      Compression::Gzip.new.decompress(@tmp_directory, @dump_filename, available_size)
    end

    protected

    def available_size
      SiteSetting.decompressed_backup_max_file_size_mb
    end

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
      @is_archive = !(@filename =~ /.sql.gz$/)

      @logs = []
      @readonly_mode_was_enabled = Discourse.readonly_mode?
      @created_functions_for_table_columns = []
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

    def validate_metadata
      log "Validating metadata..."
      log "  Current version: #{@current_version}"

      raise "Metadata has not been extracted correctly." if !@metadata

      log "  Restored version: #{@metadata["version"]}"

      error = "You're trying to restore a more recent version of the schema. You should migrate first!"
      raise error if @metadata["version"] > @current_version
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
        "#{sed_command} #{@dump_filename.gsub('.gz', '')} | #{psql_command} 2>&1"
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

      if Discourse.skip_post_deployment_migrations?
        ENV["SKIP_POST_DEPLOYMENT_MIGRATIONS"] = "0"
        Rails.application.config.paths['db/migrate'] << Rails.root.join(
          Discourse::DB_POST_MIGRATE_PATH
        ).to_s
      end

      Discourse::Application.load_tasks
      ENV["VERSION"] = @current_version.to_s
      DB.exec("SET search_path = public, pg_catalog;")
      Rake::Task["db:migrate"].invoke
    end

    def reconnect_database
      log "Reconnecting to the database..."
      RailsMultisite::ConnectionManagement::reload if RailsMultisite::ConnectionManagement::instance
      RailsMultisite::ConnectionManagement::establish_connection(db: @current_db)
    end

    def reload_site_settings
      log "Reloading site settings..."
      SiteSetting.refresh!

      DiscourseEvent.trigger(:site_settings_restored)

      if @disable_emails && SiteSetting.disable_emails == 'no'
        log "Disabling outgoing emails for non-staff users..."
        user = User.find_by_email(@user_info[:email]) || Discourse.system_user
        SiteSetting.set_and_log(:disable_emails, 'non-staff', user)
      end
    end

    def clear_emoji_cache
      log "Clearing emoji cache..."
      Emoji.clear_cache
    end

    def extract_uploads
      return unless File.exists?(File.join(@tmp_directory, 'uploads'))
      log "Extracting uploads..."

      public_uploads_path = File.join(Rails.root, "public")

      FileUtils.cd(public_uploads_path) do
        FileUtils.mkdir_p("uploads")

        tmp_uploads_path = Dir.glob(File.join(@tmp_directory, "uploads", "*")).first
        return if tmp_uploads_path.blank?
        previous_db_name = BackupMetadata.value_for("db_name") || File.basename(tmp_uploads_path)
        current_db_name = RailsMultisite::ConnectionManagement.current_db
        optimized_images_exist = File.exist?(File.join(tmp_uploads_path, 'optimized'))

        Discourse::Utils.execute_command(
          'rsync', '-avp', '--safe-links', "#{tmp_uploads_path}/", "uploads/#{current_db_name}/",
          failure_message: "Failed to restore uploads."
        )

        remap_uploads(previous_db_name, current_db_name)

        if SiteSetting.Upload.enable_s3_uploads
          migrate_to_s3
          remove_local_uploads(File.join(public_uploads_path, "uploads/#{current_db_name}"))
        end

        generate_optimized_images unless optimized_images_exist
      end
    end

    def remap_uploads(previous_db_name, current_db_name)
      log "Remapping uploads..."

      was_multisite = BackupMetadata.value_for("multisite") == "t"
      uploads_folder = was_multisite ? "/" : "/uploads/#{current_db_name}/"

      if (old_base_url = BackupMetadata.value_for("base_url")) && old_base_url != Discourse.base_url
        remap(old_base_url, Discourse.base_url)
      end

      current_s3_base_url = SiteSetting.Upload.enable_s3_uploads ? SiteSetting.Upload.s3_base_url : nil
      if (old_s3_base_url = BackupMetadata.value_for("s3_base_url")) && old_base_url != current_s3_base_url
        remap("#{old_s3_base_url}/", uploads_folder)
      end

      current_s3_cdn_url = SiteSetting.Upload.enable_s3_uploads ? SiteSetting.Upload.s3_cdn_url : nil
      if (old_s3_cdn_url = BackupMetadata.value_for("s3_cdn_url")) && old_s3_cdn_url != current_s3_cdn_url
        base_url = SiteSetting.Upload.enable_s3_uploads ? SiteSetting.Upload.s3_cdn_url : Discourse.base_url
        remap("#{old_s3_cdn_url}/", UrlHelper.schemaless("#{base_url}#{uploads_folder}"))

        old_host = URI.parse(old_s3_cdn_url).host
        new_host = URI.parse(base_url).host
        remap(old_host, new_host)
      end

      if (old_cdn_url = BackupMetadata.value_for("cdn_url")) && old_cdn_url != Discourse.asset_host
        base_url = Discourse.asset_host || Discourse.base_url
        remap("#{old_cdn_url}/", UrlHelper.schemaless("#{base_url}/"))

        old_host = URI.parse(old_cdn_url).host
        new_host = URI.parse(base_url).host
        remap(old_host, new_host)
      end

      if previous_db_name != current_db_name
        remap("uploads/#{previous_db_name}", "uploads/#{current_db_name}")
      end

    rescue => ex
      log "Something went wrong while remapping uploads.", ex
    end

    def remap(from, to)
      puts "Remapping '#{from}' to '#{to}'"
      DbHelper.remap(from, to, verbose: true, excluded_tables: ["backup_metadata"])
    end

    def migrate_to_s3
      log "Migrating uploads to S3..."
      ENV["SKIP_FAILED"] = "1"
      ENV["MIGRATE_TO_MULTISITE"] = "1" if Rails.configuration.multisite
      Rake::Task["uploads:migrate_to_s3"].invoke
      Jobs.run_later!
    end

    def remove_local_uploads(directory)
      log "Removing local uploads directory..."
      FileUtils.rm_rf(directory) if Dir[directory].present?
    rescue => ex
      log "Something went wrong while removing the following uploads directory: #{directory}", ex
    end

    def generate_optimized_images
      log 'Optimizing site icons...'
      DB.exec("TRUNCATE TABLE optimized_images")
      SiteIconManager.ensure_optimized!

      log 'Posts will be rebaked by a background job in sidekiq. You will see missing images until that has completed.'
      log 'You can expedite the process by manually running "rake posts:rebake_uncooked_posts"'

      DB.exec(<<~SQL)
        UPDATE posts
        SET baked_version = NULL
        WHERE id IN (SELECT post_id FROM post_uploads)
      SQL

      User.where("uploaded_avatar_id IS NOT NULL").find_each do |user|
        Jobs.enqueue(:create_avatar_thumbnails, upload_id: user.uploaded_avatar_id)
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

    def create_missing_discourse_functions
      log "Creating missing functions in the discourse_functions schema"

      all_readonly_table_columns = []

      Dir[Rails.root.join(Discourse::DB_POST_MIGRATE_PATH, "*.rb")].each do |path|
        require path
        class_name = File.basename(path, ".rb").sub(/^\d+_/, "").camelize
        migration_class = class_name.constantize

        if migration_class.const_defined?(:DROPPED_TABLES)
          migration_class::DROPPED_TABLES.each do |table_name|
            all_readonly_table_columns << [table_name]
          end
        end

        if migration_class.const_defined?(:DROPPED_COLUMNS)
          migration_class::DROPPED_COLUMNS.each do |table_name, column_names|
            column_names.each do |column_name|
              all_readonly_table_columns << [table_name, column_name]
            end
          end
        end
      end

      existing_function_names = Migration::BaseDropper.existing_discourse_function_names.map { |name| "#{name}()" }

      all_readonly_table_columns.each do |table_name, column_name|
        function_name = Migration::BaseDropper.readonly_function_name(table_name, column_name, with_schema: false)

        if !existing_function_names.include?(function_name)
          Migration::BaseDropper.create_readonly_function(table_name, column_name)
          @created_functions_for_table_columns << [table_name, column_name]
        end
      end
    end

    def clean_up
      log "Cleaning stuff up..."
      drop_created_discourse_functions
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
      Stylesheet::Manager.cache.clear
    end

    def drop_created_discourse_functions
      log "Dropping function from the discourse_functions schema"
      @created_functions_for_table_columns.each do |table_name, column_name|
        Migration::BaseDropper.drop_readonly_function(table_name, column_name)
      end
    rescue => ex
      log "Something went wrong while dropping functions from the discourse_functions schema", ex
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

    def after_restore_hook
      log "Executing the after_restore_hook..."
      DiscourseEvent.trigger(:restore_complete)
    end

    def log(message, ex = nil)
      return if Rails.env.test?

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
