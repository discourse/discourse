# frozen_string_literal: true

module BackupRestore

  class OperationRunningError < RuntimeError; end

  VERSION_PREFIX = "v"
  DUMP_FILE = "dump.sql.gz"
  LOGS_CHANNEL = "/admin/backups/logs"

  def self.backup!(user_id, opts = {})
    if opts[:fork] == false
      BackupRestore::Backuper.new(user_id, opts).run
    else
      start! BackupRestore::Backuper.new(user_id, opts)
    end
  end

  def self.restore!(user_id, opts = {})
    restorer = BackupRestore::Restorer.new(
      user_id: user_id,
      filename: opts[:filename],
      factory: BackupRestore::Factory.new(
        user_id: user_id,
        client_id: opts[:client_id]
      )
    )

    start! restorer
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
    Discourse.redis.setex(running_key, 60, "1")
    save_start_logs_message_id
    keep_it_running
  end

  def self.is_operation_running?
    !!Discourse.redis.get(running_key)
  end

  def self.mark_as_not_running!
    Discourse.redis.del(running_key)
  end

  def self.should_shutdown?
    !!Discourse.redis.get(shutdown_signal_key)
  end

  def self.can_rollback?
    backup_tables_count > 0
  end

  def self.operations_status
    {
      is_operation_running: is_operation_running?,
      can_rollback: can_rollback?,
      allow_restore: Rails.env.development? || SiteSetting.allow_restore
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
    ActiveRecord::Base.transaction do
      DB.exec(move_tables_between_schemas_sql(source, destination))
    end
  end

  def self.move_tables_between_schemas_sql(source, destination)
    <<~SQL
      DO $$DECLARE row record;
      BEGIN
        -- create <destination> schema if it does not exists already
        -- NOTE: DROP & CREATE SCHEMA is easier, but we don't want to drop the public schema
        -- otherwise extensions (like hstore & pg_trgm) won't work anymore...
        CREATE SCHEMA IF NOT EXISTS #{destination};
        -- move all <source> tables to <destination> schema
        FOR row IN SELECT tablename FROM pg_tables WHERE schemaname = '#{source}'
        LOOP
          EXECUTE 'DROP TABLE IF EXISTS #{destination}.' || quote_ident(row.tablename) || ' CASCADE;';
          EXECUTE 'ALTER TABLE #{source}.' || quote_ident(row.tablename) || ' SET SCHEMA #{destination};';
        END LOOP;
        -- move all <source> views to <destination> schema
        FOR row IN SELECT viewname FROM pg_views WHERE schemaname = '#{source}'
        LOOP
          EXECUTE 'DROP VIEW IF EXISTS #{destination}.' || quote_ident(row.viewname) || ' CASCADE;';
          EXECUTE 'ALTER VIEW #{source}.' || quote_ident(row.viewname) || ' SET SCHEMA #{destination};';
        END LOOP;
      END$$;
    SQL
  end

  DatabaseConfiguration = Struct.new(:host, :port, :username, :password, :database)

  def self.database_configuration
    config = ActiveRecord::Base.connection_pool.spec.config
    config = config.with_indifferent_access

    # credentials for PostgreSQL in CI environment
    if Rails.env.test?
      username = ENV["PGUSER"]
      password = ENV["PGPASSWORD"]
    end

    DatabaseConfiguration.new(
      config["backup_host"] || config["host"],
      config["backup_port"] || config["port"],
      config["username"] || username || ENV["USER"] || "postgres",
      config["password"] || password,
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
        Discourse.redis.expire(running_key, 1.minute)
        sleep 30.seconds
      end
    end
  end

  def self.shutdown_signal_key
    "backup_restore_operation_should_shutdown"
  end

  def self.set_shutdown_signal!
    Discourse.redis.set(shutdown_signal_key, "1")
  end

  def self.clear_shutdown_signal!
    Discourse.redis.del(shutdown_signal_key)
  end

  def self.save_start_logs_message_id
    id = MessageBus.last_id(LOGS_CHANNEL)
    Discourse.redis.set(start_logs_message_id_key, id)
  end

  def self.start_logs_message_id
    Discourse.redis.get(start_logs_message_id_key).to_i
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
    DB.query_single("SELECT COUNT(*) AS count FROM information_schema.tables WHERE table_schema = 'backup'").first.to_i
  end

end
