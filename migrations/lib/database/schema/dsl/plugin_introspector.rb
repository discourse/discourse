# frozen_string_literal: true

require "digest/md5"

module Migrations
  module Database
    module Schema
      module DSL
        class PluginIntrospector
          def self.compute_checksums(plugins_path)
            discover_plugins(plugins_path).transform_values { |paths| checksum_for_paths(paths) }
          end

          private_class_method def self.checksum_for_paths(paths)
            files =
              paths
                .select { |p| File.directory?(p) }
                .flat_map { |p| Dir[File.join(p, "*.rb")].sort }
                .uniq

            return "empty" if files.empty?

            digests = files.map { |f| "#{File.basename(f)}:#{Digest::MD5.file(f).hexdigest}" }
            Digest::MD5.hexdigest(digests.join("\n"))
          end

          def self.discover_plugins(plugins_path)
            plugins = {}

            Dir[File.join(plugins_path, "*")].sort.each do |plugin_dir|
              next if !File.directory?(plugin_dir)

              plugin_name = File.basename(plugin_dir)
              paths = plugin_migration_paths(plugin_dir)
              plugins[plugin_name] = paths if paths.any?
            end

            plugins
          end

          private_class_method def self.plugin_migration_paths(plugin_dir)
            %w[db/migrate db/post_migrate]
              .map { |sub| File.join(plugin_dir, sub) }
              .select { |path| File.directory?(path) }
          end

          def initialize(plugins_path: nil)
            @plugins_path = plugins_path || File.join(Rails.root, "plugins")
          end

          def introspect
            with_temporary_database do |stderr|
              run_core_migrations
              load_plugin_rake_tasks

              plugins = self.class.discover_plugins(@plugins_path)
              plugin_data, failed_plugins = introspect_plugins(plugins, stderr)
              checksums = self.class.compute_checksums(@plugins_path)

              build_result(plugin_data, checksums, failed_plugins)
            end
          end

          private

          def with_temporary_database
            original_config = ActiveRecord::Base.connection_db_config.configuration_hash.dup
            db = TemporaryDb.new

            suppress_output do |_stdout, stderr|
              db.start

              db.with_env do
                ActiveRecord::Base.establish_connection(db.connection_hash)

                yield stderr
              end
            ensure
              ActiveRecord::Base.establish_connection(original_config)
              db.stop
              db.remove
            end
          end

          def introspect_plugins(plugins, stderr)
            plugin_data = {}
            failed_plugins = []

            plugins
              .sort_by(&:first)
              .each do |plugin_name, migration_paths|
                result, failed = introspect_plugin(plugin_name, migration_paths, stderr)
                if failed
                  failed_plugins << plugin_name
                  stderr.puts(
                    "  Warning: stopping plugin introspection after '#{plugin_name}' failed to avoid partial manifest data",
                  )
                  break
                end

                plugin_data[plugin_name] = result if result
              end

            [plugin_data, failed_plugins]
          end

          def introspect_plugin(plugin_name, migration_paths, stderr)
            snapshot_before = snapshot_schema

            begin
              run_plugin_migrations(migration_paths)
            rescue StandardError => e
              stderr.puts "  Warning: '#{plugin_name}' migration error: #{e.message}"
              return nil, true
            end

            snapshot_after = snapshot_schema
            [diff_schema(snapshot_before, snapshot_after), false]
          end

          def snapshot_schema
            connection = ActiveRecord::Base.connection
            tables = connection.tables.to_set
            columns = {}

            tables.each { |table| columns[table] = connection.columns(table).map(&:name).to_set }

            { tables:, columns: }
          end

          def diff_schema(snapshot_before, snapshot_after)
            new_tables = snapshot_after[:tables] - snapshot_before[:tables]

            new_columns = {}
            snapshot_after[:columns].each do |table, cols|
              next if new_tables.include?(table)
              added = cols - snapshot_before[:columns].fetch(table, Set.new)
              new_columns[table] = added.sort if added.any?
            end

            return if new_tables.empty? && new_columns.empty?

            { "tables" => new_tables.sort, "columns" => new_columns }
          end

          def build_result(plugin_data, checksums, failed_plugins)
            {
              "plugins" => plugin_data,
              "plugin_checksums" => checksums,
              "failed_plugins" => failed_plugins.sort,
              "incomplete" => failed_plugins.any?,
            }
          end

          def core_migration_paths
            [File.join(Rails.root, "db", "migrate"), File.join(Rails.root, "db", "post_migrate")]
          end

          def run_core_migrations
            paths = core_migration_paths.select { |p| File.directory?(p) }
            ActiveRecord::MigrationContext.new(paths).migrate if paths.any?
          end

          # At least one plugin has a migration that invokes a rake task. Loading
          # all plugin rake files ensures those tasks are defined before migrations
          # run. The :environment task stub prevents errors from rake files that
          # depend on it.
          def load_plugin_rake_tasks
            Rake::Task.define_task(:environment) if !Rake::Task.task_defined?(:environment)
            Dir[File.join(@plugins_path, "*/lib/tasks/**/*.rake")].sort.each { |f| load f }
          end

          def run_plugin_migrations(paths)
            valid_paths = paths.select { |p| File.directory?(p) }
            ActiveRecord::MigrationContext.new(valid_paths).migrate if valid_paths.any?
          end

          def suppress_output
            old_stdout = $stdout
            old_stderr = $stderr
            $stdout = StringIO.new
            $stderr = StringIO.new
            yield old_stdout, old_stderr
          ensure
            $stdout = old_stdout
            $stderr = old_stderr
          end
        end
      end
    end
  end
end
