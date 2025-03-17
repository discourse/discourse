# frozen_string_literal: true

module Migration
end

class Discourse::InvalidMigration < StandardError
end

class Migration::SafeMigrate
  module SafeMigration
    @@enable_safe = true

    def self.enable_safe!
      @@enable_safe = true
    end

    def self.disable_safe!
      @@enable_safe = false
    end

    def migrate(direction)
      if direction == :up && version &&
           version > Migration::SafeMigrate.earliest_post_deploy_version &&
           @@enable_safe != false && !is_post_deploy_migration?
        Migration::SafeMigrate.enable!
      end

      super
    ensure
      Migration::SafeMigrate.disable!
    end

    private

    def is_post_deploy_migration?
      instance_methods = self.class.instance_methods(false)

      method =
        if instance_methods.include?(:up)
          :up
        elsif instance_methods.include?(:change)
          :change
        end

      return false if !method

      self.method(method).source_location.first.include?(Discourse::DB_POST_MIGRATE_PATH)
    end
  end

  module NiceErrors
    def migrate
      super
    rescue => e
      if e.cause.is_a?(Discourse::InvalidMigration)
        def e.cause
          nil
        end

        def e.backtrace
          super.reject do |frame|
            frame =~ /safe_migrate\.rb/ || frame =~ /schema_migration_details\.rb/
          end
        end
        raise e
      else
        raise e
      end
    end
  end

  def self.post_migration_path
    Discourse::DB_POST_MIGRATE_PATH
  end

  def self.enable!
    return if PG::Connection.method_defined?(:exec_migrator_unpatched)
    return if ENV["RAILS_ENV"] == "production"

    @@migration_sqls = []
    @@activerecord_remove_indexes = []

    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
      alias_method :original_remove_index, :remove_index

      def remove_index(table_name, column_name = nil, **options)
        @@activerecord_remove_indexes << (
          options[:name] || index_name(table_name, options.merge(column: column_name))
        )

        # Call the original method
        original_remove_index(table_name, column_name, **options)
      end
    end

    PG::Connection.class_eval do
      alias_method :exec_migrator_unpatched, :exec
      alias_method :async_exec_migrator_unpatched, :async_exec

      def exec(*args, &blk)
        Migration::SafeMigrate.protect!(args[0])
        exec_migrator_unpatched(*args, &blk)
      end

      def async_exec(*args, &blk)
        Migration::SafeMigrate.protect!(args[0])
        async_exec_migrator_unpatched(*args, &blk)
      end
    end
  end

  def self.disable!
    return if !PG::Connection.method_defined?(:exec_migrator_unpatched)
    return if ENV["RAILS_ENV"] == "production"

    @@migration_sqls.clear
    @@activerecord_remove_indexes.clear

    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
      alias_method :remove_index, :original_remove_index
      remove_method :original_remove_index
    end

    PG::Connection.class_eval do
      alias_method :exec, :exec_migrator_unpatched
      alias_method :async_exec, :async_exec_migrator_unpatched

      remove_method :exec_migrator_unpatched
      remove_method :async_exec_migrator_unpatched
    end
  end

  def self.patch_active_record!
    return if ENV["RAILS_ENV"] == "production"

    ActiveSupport.on_load(:active_record) { ActiveRecord::Migration.prepend(SafeMigration) }

    if defined?(ActiveRecord::Tasks::DatabaseTasks)
      ActiveRecord::Tasks::DatabaseTasks.singleton_class.prepend(NiceErrors)
    end
  end

  def self.protect!(sql)
    @@migration_sqls << sql

    if sql =~ /\A\s*(?:drop\s+table|alter\s+table.*rename\s+to)\s+/i
      $stdout.puts("", <<~TEXT)
        WARNING
        -------------------------------------------------------------------------------------
        An attempt was made to drop or rename a table in a migration
        SQL used was: '#{sql}'
        Please generate a post deployment migration using `rails g post_migration` to drop
        or rename the table.

        This protection is in place to protect us against dropping tables that are currently
        in use by live applications.
      TEXT
      raise Discourse::InvalidMigration, "Attempt was made to drop a table"
    elsif sql =~ /\A\s*alter\s+table.*(?:rename|drop(?!\s+not\s+null))\s+/i
      $stdout.puts("", <<~TEXT)
        WARNING
        -------------------------------------------------------------------------------------
        An attempt was made to drop or rename a column in a migration
        SQL used was: '#{sql}'

        Please generate a post deployment migration using `rails g post_migration` to drop
        or rename columns.

        Note, to minimize disruption use self.ignored_columns = ["column name"] on your
        ActiveRecord model, this can be removed after the post deployment migration has been promoted to a regular migration.

        This protection is in place to protect us against dropping columns that are currently
        in use by live applications.
      TEXT
      raise Discourse::InvalidMigration, "Attempt was made to rename or delete column"
    elsif sql =~ /\A\s*create\s+(?:unique\s+)?index\s+concurrently\s+/i
      index_name =
        sql.match(/\bINDEX\s+CONCURRENTLY\s+(?:IF\s+NOT\s+EXISTS\s+)?"?([a-zA-Z0-9_\.]+)"?/i)[1]

      return if @@activerecord_remove_indexes.include?(index_name)

      match = sql.match(/\bON\s+(?:ONLY\s+)?(?:"([^"]+)"|([a-zA-Z0-9_\.]+))/i)
      table_name = match[1] || match[2]

      has_drop_index_statement =
        @@migration_sqls.any? do |migration_sql|
          migration_sql =~ /\A\s*drop\s+index/i && migration_sql.include?(table_name) &&
            migration_sql.include?(index_name)
        end

      return if has_drop_index_statement

      raise(Discourse::InvalidMigration, <<~RAW)
      WARNING
      -------------------------------------------------------------------------------------
      An attempt was made to create an index concurrently in a migration without first dropping the index.
      SQL used was: '#{sql}'

      Per postgres documentation:

        If a problem arises while scanning the table, such as a deadlock or a uniqueness violation in a unique index,
        the CREATE INDEX command will fail but leave behind an “invalid” index. This index will be ignored for querying
        purposes because it might be incomplete; however it will still consume update overhead. The recommended recovery
        method in such cases is to drop the index and try again to perform CREATE INDEX CONCURRENTLY .

      Please update the migration to first drop the index if it exists before creating it concurrently.
      RAW
    end
  end

  def self.earliest_post_deploy_version
    @@earliest_post_deploy_version ||=
      begin
        first_file = Dir.glob("#{Discourse::DB_POST_MIGRATE_PATH}/*.rb").sort.first
        file_name = File.basename(first_file, ".rb")
        file_name.first(14).to_i
      end
  end
end
