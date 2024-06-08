# frozen_string_literal: true

module Migrations::IntermediateDB
  class Migrator
    def self.migrate(db_path, migrations_path: nil)
      self.new(db_path, migrations_path).migrate
    end

    def self.reset!(db_path)
      self.new(db_path).reset!
    end

    def initialize(db_path, migrations_path = nil)
      @db_path = db_path
      @migrations_path = migrations_path
      @db = nil
    end

    def migrate
      @db = Connection.open_database(path: @db_path)

      if new_database?
        create_schema_migrations_table
        performed_migrations = Set.new
      else
        performed_migrations = find_performed_migrations
      end

      path = @migrations_path || File.join(::Migrations.root_path, "db", "schema")
      migrate_from_path(path, performed_migrations)

      @db.close
    end

    def reset!
      [@db_path, "#{@db_path}-wal", "#{@db_path}-shm"].each do |path|
        FileUtils.remove_file(path, force: true) if File.exist?(path)
      end
    end

    private

    def new_database?
      @db.query_single_splat(<<~SQL) == 0
        SELECT COUNT(*)
        FROM sqlite_schema
        WHERE type = 'table' AND name = 'schema_migrations'
      SQL
    end

    def find_performed_migrations
      @db.query_splat(<<~SQL).to_set
        SELECT path
        FROM schema_migrations
      SQL
    end

    def create_schema_migrations_table
      @db.execute(<<~SQL)
        CREATE TABLE schema_migrations
        (
            path       TEXT     NOT NULL PRIMARY KEY,
            created_at DATETIME NOT NULL,
            sql_hash   TEXT     NOT NULL
        );
      SQL
    end

    def migrate_from_path(migration_path, performed_migrations)
      file_pattern = File.join(migration_path, "*.sql")
      root_path = @migrations_path || Migrations.root_path

      Dir[file_pattern].sort.each do |path|
        relative_path = Pathname(path).relative_path_from(root_path).to_s

        if performed_migrations.exclude?(relative_path)
          sql = File.read(path)
          sql_hash = Digest::SHA1.hexdigest(sql)

          @db.transaction do
            @db.execute(sql)
            @db.execute(<<~SQL, path: relative_path, sql_hash: sql_hash)
              INSERT INTO schema_migrations (path, created_at, sql_hash)
              VALUES (:path, datetime('now'), :sql_hash)
            SQL
          end
        end
      end
    end
  end
end
