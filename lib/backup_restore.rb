require_dependency "export/exporter"
require_dependency "import/importer"

module BackupRestore

  class OperationRunningError < RuntimeError; end

  DUMP_FILE = "dump.sql"
  METADATA_FILE = "meta.json"
  LOGS_CHANNEL = "/admin/backups/logs"

  def self.backup!(user_id, publish_to_message_bus = false)
    exporter = Export::Exporter.new(user_id, publish_to_message_bus)
    start! exporter
  end

  def self.restore!(user_id, filename, publish_to_message_bus = false)
    importer = Import::Importer.new(user_id, filename, publish_to_message_bus)
    start! importer
  end

  def self.rollback!
    raise BackupRestore::OperationRunningError if BackupRestore.is_operation_running?
    if can_rollback?
      move_tables_between_schemas("backup", "public")
      after_fork
    end
  end

  def self.cancel!
    set_shutdown_signal!
    true
  end

  def self.mark_as_running!
    # TODO: for extra safety, it should acquire a lock and raise an exception if already running
    $redis.set(running_key, "1")
    save_start_logs_message_id
    keep_it_running
  end

  def self.is_operation_running?
    !!$redis.get(running_key)
  end

  def self.mark_as_not_running!
    $redis.del(running_key)
  end

  def self.should_shutdown?
    !!$redis.get(shutdown_signal_key)
  end

  def self.can_rollback?
    backup_tables_count > 0
  end

  def self.operations_status
    {
      is_operation_running: is_operation_running?,
      can_rollback: can_rollback?,
    }
  end

  def self.logs
    id = start_logs_message_id
    MessageBus.backlog(LOGS_CHANNEL, id).map { |m| m.data }
  end

  def self.current_version
    ActiveRecord::Migrator.current_version
  end

  def self.move_tables_between_schemas(source, destination)
    User.exec_sql(move_tables_between_schemas_sql(source, destination))
  end

  def self.move_tables_between_schemas_sql(source, destination)
    # TODO: Postgres 9.3 has "CREATE SCHEMA schema IF NOT EXISTS;"
    <<-SQL
      DO $$DECLARE row record;
      BEGIN
        -- create <destination> schema if it does not exists already
        -- NOTE: DROP & CREATE SCHEMA is easier, but we don't want to drop the public schema
        -- ortherwise extensions (like hstore & pg_trgm) won't work anymore...
        IF NOT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname = '#{destination}')
        THEN
          CREATE SCHEMA #{destination};
        END IF;
        -- move all <source> tables to <destination> schema
        FOR row IN SELECT tablename FROM pg_tables WHERE schemaname = '#{source}'
        LOOP
          EXECUTE 'DROP TABLE IF EXISTS #{destination}.' || quote_ident(row.tablename) || ' CASCADE;';
          EXECUTE 'ALTER TABLE #{source}.' || quote_ident(row.tablename) || ' SET SCHEMA #{destination};';
        END LOOP;
      END$$;
    SQL
  end

  DatabaseConfiguration = Struct.new(:host, :username, :password, :database)

  def self.database_configuration
    config = Rails.env.production? ? ActiveRecord::Base.connection_pool.spec.config : Rails.configuration.database_configuration[Rails.env]
    config = config.with_indifferent_access

    DatabaseConfiguration.new(
      config["host"],
      config["username"] || ENV["USER"] || "postgres",
      config["password"],
      config["database"]
    )
  end

  private

  def self.running_key
    "backup_restore_operation_is_running"
  end

  def self.keep_it_running
    # extend the expiry by 1 minute every 30 seconds
    Thread.new do
      # this thread will be killed when the fork dies
      while true
        $redis.expire(running_key, 1.minute)
        sleep 30.seconds
      end
    end
  end

  def self.shutdown_signal_key
    "backup_restore_operation_should_shutdown"
  end

  def self.set_shutdown_signal!
    $redis.set(shutdown_signal_key, "1")
  end

  def self.clear_shutdown_signal!
    $redis.del(shutdown_signal_key)
  end

  def self.save_start_logs_message_id
    id = MessageBus.last_id(LOGS_CHANNEL)
    $redis.set(start_logs_message_id_key, id)
  end

  def self.start_logs_message_id
    $redis.get(start_logs_message_id_key).to_i
  end

  def self.start_logs_message_id_key
    "start_logs_message_id"
  end

  def self.start!(runner)
    child = fork do
      begin
        after_fork
        runner.run
      rescue Exception => e
        puts "--------------------------------------------"
        puts "---------------- EXCEPTION -----------------"
        puts e.message
        puts e.backtrace.join("\n")
        puts "--------------------------------------------"
      ensure
        begin
          clear_shutdown_signal!
        rescue Exception => e
          puts "============================================"
          puts "================ EXCEPTION ================="
          puts e.message
          puts e.backtrace.join("\n")
          puts "============================================"
        ensure
          exit!(0)
        end
      end
    end

    Process.detach(child)

    true
  end

  def self.after_fork
    Discourse.after_fork
  end

  def self.backup_tables_count
    User.exec_sql("SELECT COUNT(*) AS count FROM information_schema.tables WHERE table_schema = 'backup'")[0]['count'].to_i
  end

end
