# frozen_string_literal: true

module BackupRestore
  DatabaseRestoreError = Class.new(RuntimeError)

  class DatabaseRestorer
    delegate :log, to: :@logger, private: true

    MAIN_SCHEMA = "public"
    BACKUP_SCHEMA = "backup"
    DROP_BACKUP_SCHEMA_AFTER_DAYS = 7

    def initialize(logger, current_db)
      @logger = logger
      @db_was_changed = false
      @current_db = current_db
    end

    def restore(db_dump_path)
      BackupRestore.move_tables_between_schemas(MAIN_SCHEMA, BACKUP_SCHEMA)

      @db_dump_path = db_dump_path
      @db_was_changed = true

      create_missing_discourse_functions
      restore_dump
      migrate_database
      reconnect_database

      self.class.update_last_restore_date
    end

    def rollback
      log "Trying to rollback..."

      if @db_was_changed && BackupRestore.can_rollback?
        log "Rolling back..."
        BackupRestore.move_tables_between_schemas(BACKUP_SCHEMA, MAIN_SCHEMA)
      else
        log "There was no need to rollback"
      end
    end

    def clean_up
      drop_created_discourse_functions
    end

    def self.drop_backup_schema
      if backup_schema_dropable?
        ActiveRecord::Base.connection.drop_schema(BACKUP_SCHEMA)
      end
    end

    def self.update_last_restore_date
      BackupMetadata.where(name: BackupMetadata::LAST_RESTORE_DATE).delete_all
      BackupMetadata.create!(
        name: BackupMetadata::LAST_RESTORE_DATE,
        value: Time.zone.now.iso8601
      )
    end

    protected

    def restore_dump
      log "Restoring dump file... (this may take a while)"

      logs = Queue.new
      last_line = nil
      psql_running = true

      log_thread = Thread.new do
        RailsMultisite::ConnectionManagement::establish_connection(db: @current_db)
        while psql_running
          message = logs.pop.strip
          log(message) if message.present?
        end
      end

      IO.popen(restore_dump_command) do |pipe|
        begin
          while line = pipe.readline
            logs << line
            last_line = line
          end
        rescue EOFError
          # finished reading...
        ensure
          psql_running = false
        end
      end

      logs << ""
      log_thread.join

      raise DatabaseRestoreError.new("psql failed: #{last_line}") if Process.last_status&.exitstatus != 0
    end

    # Removes unwanted SQL added by certain versions of pg_dump.
    def sed_command
      unwanted_sql = [
        "DROP SCHEMA", # Discourse <= v1.5
        "CREATE SCHEMA", # PostgreSQL 11+
        "COMMENT ON SCHEMA", # PostgreSQL 11+
        "SET default_table_access_method" # PostgreSQL 12
      ].join("|")

      "sed -E '/^(#{unwanted_sql})/d'"
    end

    def restore_dump_command
      "#{sed_command} #{@db_dump_path} | #{self.class.psql_command} 2>&1"
    end

    def self.psql_command
      db_conf = BackupRestore.database_configuration

      password_argument = "PGPASSWORD='#{db_conf.password}'" if db_conf.password.present?
      host_argument     = "--host=#{db_conf.host}"           if db_conf.host.present?
      port_argument     = "--port=#{db_conf.port}"           if db_conf.port.present?
      username_argument = "--username=#{db_conf.username}"   if db_conf.username.present?

      [ password_argument,                # pass the password to psql (if any)
        "psql",                           # the psql command
        "--dbname='#{db_conf.database}'", # connect to database *dbname*
        "--single-transaction",           # all or nothing (also runs COPY commands faster)
        "--variable=ON_ERROR_STOP=1",     # stop on first error
        host_argument,                    # the hostname to connect to (if any)
        port_argument,                    # the port to connect to (if any)
        username_argument                 # the username to connect as (if any)
      ].compact.join(" ")
    end

    def migrate_database
      log "Migrating the database..."

      log Discourse::Utils.execute_command(
        { "SKIP_POST_DEPLOYMENT_MIGRATIONS" => "0" },
        "rake db:migrate",
        failure_message: "Failed to migrate database.",
        chdir: Rails.root
      )
    end

    def reconnect_database
      log "Reconnecting to the database..."
      RailsMultisite::ConnectionManagement::reload if RailsMultisite::ConnectionManagement::instance
      RailsMultisite::ConnectionManagement::establish_connection(db: @current_db)
    end

    def create_missing_discourse_functions
      log "Creating missing functions in the discourse_functions schema..."

      @created_functions_for_table_columns = []
      all_readonly_table_columns = []

      Dir[Rails.root.join(Migration::SafeMigrate.post_migration_path, "**/*.rb")].each do |path|
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

    def drop_created_discourse_functions
      return if @created_functions_for_table_columns.blank?

      log "Dropping functions from the discourse_functions schema..."
      @created_functions_for_table_columns.each do |table_name, column_name|
        Migration::BaseDropper.drop_readonly_function(table_name, column_name)
      end
    rescue => ex
      log "Something went wrong while dropping functions from the discourse_functions schema", ex
    end

    def self.backup_schema_dropable?
      return false unless ActiveRecord::Base.connection.schema_exists?(BACKUP_SCHEMA)

      last_restore_date = BackupMetadata.value_for(BackupMetadata::LAST_RESTORE_DATE)

      if last_restore_date.present?
        last_restore_date = Time.zone.parse(last_restore_date)
        return last_restore_date + DROP_BACKUP_SCHEMA_AFTER_DAYS.days < Time.zone.now
      end

      update_last_restore_date
      false
    end
    private_class_method :backup_schema_dropable?
  end
end
