# frozen_string_literal: true

require "digest/md5"

module Migrations::Database::Schema::DSL
  class PluginIntrospector
    def initialize(plugins_path: nil)
      @plugins_path = plugins_path || File.join(Rails.root, "plugins")
    end

    def introspect
      original_config = ActiveRecord::Base.connection_db_config.configuration_hash.dup
      db = TemporaryDb.new
      real_stderr = $stderr

      suppress_output do
        begin
          db.start

          db.with_env do
            ActiveRecord::Base.establish_connection(
              adapter: "postgresql",
              database: "discourse",
              port: db.pg_port,
              host: "localhost",
            )

            run_core_migrations
            load_plugin_rake_tasks

            plugins = discover_plugins
            plugin_data = {}
            failed_plugins = []

            plugins.keys.sort.each do |plugin_name|
              migration_paths = plugins[plugin_name]
              snapshot_before = snapshot_schema

              begin
                run_plugin_migrations(migration_paths)
              rescue StandardError => e
                failed_plugins << plugin_name
                real_stderr.puts "  Warning: '#{plugin_name}' migration error: #{e.message}"
              end

              snapshot_after = snapshot_schema

              new_tables = (snapshot_after[:tables] - snapshot_before[:tables]).sort
              new_table_set = new_tables.to_set

              # Only track columns added to tables the plugin doesn't own
              new_columns = {}
              snapshot_after[:columns].each do |table, cols|
                next if new_table_set.include?(table)
                before_cols = snapshot_before[:columns].fetch(table, Set.new)
                added = (cols - before_cols).sort
                new_columns[table] = added if added.any?
              end

              if new_tables.any? || new_columns.any?
                plugin_data[plugin_name] = { "tables" => new_tables, "columns" => new_columns }
              end
            end

            checksums = compute_all_checksums

            {
              "plugins" => plugin_data,
              "migration_state" => checksums,
              "failed_plugins" => failed_plugins.sort,
              "incomplete" => failed_plugins.any?,
            }
          end
        ensure
          ActiveRecord::Base.establish_connection(original_config)
          db.stop
          db.remove
        end
      end
    end

    def compute_all_checksums
      core = compute_checksum_for_paths(core_migration_paths)
      plugin_checksums = compute_plugin_checksums
      { "core" => core, "plugins" => plugin_checksums }
    end

    def compute_plugin_checksums
      checksums = {}
      discover_plugins.each { |name, paths| checksums[name] = compute_checksum_for_paths(paths) }
      checksums
    end

    def discover_plugins
      plugins = {}

      Dir[File.join(@plugins_path, "*")].sort.each do |plugin_dir|
        next unless File.directory?(plugin_dir)

        plugin_name = File.basename(plugin_dir)
        paths = plugin_migration_paths(plugin_dir)
        plugins[plugin_name] = paths if paths.any?
      end

      plugins
    end

    def compute_checksum_for_paths(paths)
      files =
        paths.select { |p| File.directory?(p) }.flat_map { |p| Dir[File.join(p, "*.rb")].sort }.uniq

      return "empty" if files.empty?

      digests = files.map { |f| "#{File.basename(f)}:#{Digest::MD5.file(f).hexdigest}" }
      Digest::MD5.hexdigest(digests.join("\n"))
    end

    private

    def core_migration_paths
      [File.join(Rails.root, "db", "migrate"), File.join(Rails.root, "db", "post_migrate")]
    end

    def plugin_migration_paths(plugin_dir)
      paths = []
      %w[db/migrate db/post_migrate].each do |sub|
        path = File.join(plugin_dir, sub)
        paths << path if File.directory?(path)
      end
      paths
    end

    def run_core_migrations
      paths = core_migration_paths.select { |p| File.directory?(p) }
      return if paths.empty?
      ActiveRecord::MigrationContext.new(paths).migrate
    end

    def load_plugin_rake_tasks
      Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
      Dir[File.join(@plugins_path, "*/lib/tasks/**/*.rake")].sort.each { |f| load f }
    end

    def run_plugin_migrations(paths)
      valid_paths = paths.select { |p| File.directory?(p) }
      return if valid_paths.empty?
      ActiveRecord::MigrationContext.new(valid_paths).migrate
    end

    def snapshot_schema
      connection = ActiveRecord::Base.connection
      tables = connection.tables.to_set
      columns = {}

      tables.each { |table| columns[table] = connection.columns(table).map(&:name).to_set }

      { tables:, columns: }
    end

    def suppress_output
      old_stdout = $stdout
      old_stderr = $stderr
      $stdout = StringIO.new
      $stderr = StringIO.new
      yield
    ensure
      $stdout = old_stdout
      $stderr = old_stderr
    end
  end
end
