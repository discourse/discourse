# frozen_string_literal: true

module Migrations::Database
  module Schema
    Definition = Data.define(:tables, :enums)
    TableDefinition =
      Data.define(
        :name,
        :columns,
        :indexes,
        :primary_key_column_names,
        :constraints,
        :model_mode,
      ) do
        def sorted_columns
          pk_position = primary_key_column_names.each_with_index.to_h
          columns.sort_by { |c| [c.is_primary_key ? 0 : 1, pk_position.fetch(c.name, 0), c.name] }
        end
      end
    ColumnDefinition = Data.define(:name, :datatype, :nullable, :max_length, :is_primary_key, :enum)
    IndexDefinition = Data.define(:name, :column_names, :unique, :condition)
    ConstraintDefinition = Data.define(:name, :type, :condition)
    EnumDefinition = Data.define(:name, :values, :datatype)

    class ConfigError < StandardError
    end

    class GenerationError < StandardError
    end

    # --- DSL Registration Methods ---

    def self.configure(&block)
      builder = DSL::ConfigBuilder.new
      builder.instance_eval(&block)
      registry.register_config(builder.build)
    end

    def self.conventions(&block)
      builder = DSL::ConventionsBuilder.new
      builder.instance_eval(&block)
      registry.register_conventions(builder.build)
    end

    def self.table(name, &block)
      builder = DSL::TableBuilder.new(name)
      if block
        builder.instance_eval(&block)
      else
        builder.include_all
      end
      registry.register_table(name, builder.build)
    end

    def self.enum(name, &block)
      builder = DSL::EnumBuilder.new(name)
      builder.instance_eval(&block)
      registry.register_enum(name, builder.build)
    end

    def self.ignored(&block)
      builder = DSL::IgnoredBuilder.new
      builder.instance_eval(&block)
      registry.register_ignored(builder.build)
    end

    # --- Accessor Methods ---

    def self.tables
      registry.tables
    end

    def self.find_table(name)
      registry.table(name)
    end

    def self.enums
      registry.enums
    end

    def self.config
      registry.config
    end

    def self.conventions_config
      registry.conventions_config
    end

    def self.ignored_tables
      registry.ignored_tables
    end

    def self.plugin_manifest
      @plugin_manifest ||=
        DSL::PluginManifest.new(manifest_path:, plugins_path: File.join(Rails.root, "plugins"))
    end

    # --- Validation, Resolution & Generation ---

    def self.validate(database: :intermediate_db)
      ensure_ready!(database:)
      DSL::Validator.new(self).validate
    end

    def self.resolve(database: :intermediate_db)
      ensure_ready!(database:)
      DSL::SchemaResolver.new(self).resolve
    end

    def self.generate(database: :intermediate_db)
      ensure_ready!(database:)
      DSL::Generator.new(self).generate
    end

    def self.diff(database: :intermediate_db)
      ensure_ready!(database:)
      DSL::Differ.new(self).diff
    end

    def self.add_table(table_name, database: :intermediate_db)
      ensure_ready!(database:)
      DSL::Scaffolder.new(self, table_name, database:).scaffold!
    end

    def self.ignore_table(table_name, reason: nil, database: :intermediate_db)
      DSL::IgnoredFileEditor.new(config_path(database)).add_table(table_name, reason:)
    end

    # --- Lifecycle Methods ---

    def self.ensure_ready!(database: :intermediate_db, refresh_manifest: true)
      db_key = database.to_sym
      path = config_path(database)

      unless File.directory?(schema_root_path)
        raise ConfigError, I18n.t("schema.config_root_not_found", path: schema_root_path)
      end

      unless File.directory?(path)
        available = available_databases.join(", ")
        raise ConfigError, I18n.t("schema.unknown_database", name: database, available:)
      end

      return if @ready == db_key

      reset!
      begin
        DSL::Loader.new(path).load!
        registry.freeze!

        if refresh_manifest
          manifest = plugin_manifest
          unless manifest.checksums_fresh?
            begin
              $stdout.write(I18n.t("schema.detect_plugins.auto_detecting"))
              manifest.regenerate!
              if manifest.incomplete?
                failed_plugins = manifest.failed_plugins.join(", ").presence || "(unknown)"
                puts I18n.t("schema.detect_plugins.auto_incomplete", failed_plugins:)
              else
                puts I18n.t(
                       "schema.detect_plugins.auto_done",
                       tables: manifest.table_count,
                       columns: manifest.column_count,
                     )
              end
            rescue StandardError => e
              message = I18n.t("schema.detect_plugins.auto_failed", error: e.message)
              puts message
              raise ConfigError, message
            end
          end
        end

        @ready = db_key
      rescue StandardError
        # Avoid keeping partially loaded DSL state after loader/refresh failures.
        reset!
        raise
      end
    end

    def self.schema_root_path
      File.join(Migrations.root_path, "config", "schema")
    end

    def self.config_path(database = :intermediate_db)
      File.join(schema_root_path, database.to_s)
    end

    def self.manifest_path
      File.join(Migrations.root_path, "config", "schema", "plugin_manifest.yml")
    end

    def self.available_databases
      dir = schema_root_path
      return [] unless File.directory?(dir)

      Dir.children(dir).select { |d| File.directory?(File.join(dir, d)) }.sort
    end

    def self.reset!
      @registry = nil
      @ready = nil
      @plugin_manifest = nil
    end

    def self.registry
      @registry ||= DSL::Registry.new
    end
    private_class_method :registry, :manifest_path
  end
end
