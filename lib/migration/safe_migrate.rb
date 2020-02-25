# frozen_string_literal: true

module Migration; end

class Discourse::InvalidMigration < StandardError; end

class Migration::SafeMigrate
  module SafeMigration
    UNSAFE_VERSION = 20180321015220
    @@enable_safe = true

    def self.enable_safe!
      @@enable_safe = true
    end

    def self.disable_safe!
      @@enable_safe = false
    end

    def migrate(direction)
      if direction == :up &&
         version && version > UNSAFE_VERSION &&
         @@enable_safe != false &&
         !is_post_deploy_migration?

        Migration::SafeMigrate.enable!
      end

      super
    ensure
      Migration::SafeMigrate.disable!
    end

    private

    def is_post_deploy_migration?
      method =
        if self.respond_to?(:up)
          :up
        elsif self.respond_to?(:change)
          :change
        end

      self.method(method).source_location.first.include?(
        Discourse::DB_POST_MIGRATE_PATH
      )
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
    PG::Connection.class_eval do
      alias_method :exec, :exec_migrator_unpatched
      alias_method :async_exec, :async_exec_migrator_unpatched

      remove_method :exec_migrator_unpatched
      remove_method :async_exec_migrator_unpatched
    end
  end

  def self.patch_active_record!
    ActiveSupport.on_load(:active_record) do
      ActiveRecord::Migration.prepend(SafeMigration)
    end

    if defined?(ActiveRecord::Tasks::DatabaseTasks)
      ActiveRecord::Tasks::DatabaseTasks.singleton_class.prepend(NiceErrors)
    end
  end

  def self.protect!(sql)
    if sql =~ /^\s*(?:drop\s+table|alter\s+table.*rename\s+to)\s+/i
      $stdout.puts("", <<~STR)
        WARNING
        -------------------------------------------------------------------------------------
        An attempt was made to drop or rename a table in a migration
        SQL used was: '#{sql}'
        Please generate a post deployment migration using `rails g post_migration` to drop
        or rename the table.

        This protection is in place to protect us against dropping tables that are currently
        in use by live applications.
      STR
      raise Discourse::InvalidMigration, "Attempt was made to drop a table"
    elsif sql =~ /^\s*alter\s+table.*(?:rename|drop)\s+/i
      $stdout.puts("", <<~STR)
        WARNING
        -------------------------------------------------------------------------------------
        An attempt was made to drop or rename a column in a migration
        SQL used was: '#{sql}'

        Please generate a post deployment migration using `rails g post_migration` to drop
        or rename columns.

        Note, to minimize disruption use self.ignored_columns = ["column name"] on your
        ActiveRecord model, this can be removed 6 months or so later.

        This protection is in place to protect us against dropping columns that are currently
        in use by live applications.
      STR
      raise Discourse::InvalidMigration, "Attempt was made to rename or delete column"
    end
  end
end
