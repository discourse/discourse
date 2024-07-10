# frozen_string_literal: true

module Migrations
  class IntermediateDatabaseMigrator
    class << self
      def reset!(path)
        [path, "#{path}-wal", "#{path}-shm"].each { |p| FileUtils.rm_f(p) if File.exist?(p) }
      end

      def migrate(path)
        connection = IntermediateDatabase.create_connection(path: path)
        performed_migrations = find_performed_migrations(connection)

        path = File.join(::Migrations.root_path, "db", "schema")
        migrate_from_path(connection, path, performed_migrations)

        connection.close
      end

      private

      def new_database?(connection)
        connection.query_single_splat(<<~SQL) == 0
          SELECT COUNT(*)
          FROM sqlite_schema
          WHERE type = 'table' AND name = 'schema_migrations'
        SQL
      end

      def find_performed_migrations(connection)
        return Set.new if new_database?(connection)

        connection.query_splat(<<~SQL).to_set
          SELECT path
          FROM schema_migrations
        SQL
      end

      def migrate_from_path(connection, migration_path, performed_migrations)
        file_pattern = File.join(migration_path, "*.sql")
        Dir[file_pattern].sort.each do |path|
          relative_path = Pathname(path).relative_path_from(Migrations.root_path).to_s

          if performed_migrations.exclude?(relative_path)
            sql = File.read(path)
            sql_hash = Digest::SHA1.hexdigest(sql)
            connection.execute(sql)

            connection.execute(<<~SQL, path: relative_path, sql_hash: sql_hash)
              INSERT INTO schema_migrations (path, created_at, sql_hash)
              VALUES (:path, datetime('now'), :sql_hash)
            SQL
          end
        end
      end
    end
  end
end
