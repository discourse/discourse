# frozen_string_literal: true

require "extralite"

module Migrations
  class IntermediateDb
    class << self
      def create_connection(path)
        db = Extralite::Database.new(path)
        db.pragma(busy_timeout: 60_000) # 60 seconds
        db.pragma(auto_vacuum: "full")
        db.pragma(journal_mode: "wal")
        db.pragma(synchronous: "off")
        db
      end

      def reset!(path)
        [path, "#{path}-wal", "#{path}-shm"].each { |p| FileUtils.rm_f(p) if File.exist?(p) }
      end

      def migrate(path)
        connection = create_connection(path)
        performed_migrations = find_performed_migrations(connection)

        path = File.join(__dir__, "intermediate_db_schema")
        migrate_from_path(connection, path, performed_migrations)

        connection.close
      end

      def open
        db = self.class.new
        yield(db)
      ensure
        db.close if db
      end

      private

      def new_database?(connection)
        connection.query_single_value(<<~SQL) == 0
          SELECT COUNT(*)
          FROM sqlite_master
          WHERE type = 'table' AND name = 'schema_migrations'
        SQL
      end

      def find_performed_migrations(connection)
        return Set.new if new_database?(connection)

        connection.execute(<<~SQL).to_a.to_set
          SELECT path
          FROM schema_migrations
        SQL
      end

      def migrate_from_path(connection, migration_path, performed_migrations)
        file_pattern = File.join(migration_path, "*.sql")
        Dir[file_pattern].sort.each do |path|
          relative_path = Pathname(path).relative_path_from(__dir__).to_s

          unless performed_migrations.include?(relative_path)
            sql = File.read(path)
            connection.execute(sql)

            connection.execute(<<~SQL, path: relative_path)
              INSERT INTO schema_migrations (path, created_at)
              VALUES (:path, datetime('now'))
            SQL
          end
        end
      end
    end
  end
end
