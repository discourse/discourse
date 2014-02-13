require_dependency "export/exporter"
require_dependency "import/importer"

module BackupRestore

  class OperationRunningError < RuntimeError; end

  DUMP_FILE = "dump.sql"
  METADATA_FILE = "meta.json"

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
      rename_schema("backup", "public")
      establish_app
    end
  end

  def self.cancel!
    set_shutdown_signal!
    true
  end

  def self.mark_as_running!
    # TODO: should acquire a lock and raise an exception if already running!
    $redis.set(running_key, "1")
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

  def self.current_version
    ActiveRecord::Migrator.current_version
  end

  def self.can_rollback?
    User.exec_sql("SELECT 1 FROM pg_namespace WHERE nspname = 'backup'").count > 0
  end

  def self.rename_schema(old_name, new_name)
    sql = <<-SQL
      BEGIN;
        DROP SCHEMA IF EXISTS #{new_name} CASCADE;
        ALTER SCHEMA #{old_name} RENAME TO #{new_name};
      COMMIT;
    SQL

    User.exec_sql(sql)
  end

  private

  def self.running_key
    "backup_restore_operation_is_running"
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
    $redis.client.reconnect
    Rails.cache.reconnect
    MessageBus.after_fork
  end

  def self.backup_tables_count
    User.exec_sql("SELECT COUNT(*) AS count FROM information_schema.tables WHERE table_schema = 'backup'")[0]['count'].to_i
  end

end
