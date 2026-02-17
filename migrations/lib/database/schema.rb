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

    SQLITE_KEYWORDS = %w[
      abort
      action
      add
      after
      all
      alter
      always
      analyze
      and
      as
      asc
      attach
      autoincrement
      before
      begin
      between
      by
      cascade
      case
      cast
      check
      collate
      column
      commit
      conflict
      constraint
      create
      cross
      current
      current_date
      current_time
      current_timestamp
      database
      default
      deferrable
      deferred
      delete
      desc
      detach
      distinct
      do
      drop
      each
      else
      end
      escape
      except
      exclude
      exclusive
      exists
      explain
      fail
      filter
      first
      following
      for
      foreign
      from
      full
      generated
      glob
      group
      groups
      having
      if
      ignore
      immediate
      in
      index
      indexed
      initially
      inner
      insert
      instead
      intersect
      into
      is
      isnull
      join
      key
      last
      left
      like
      limit
      match
      materialized
      natural
      no
      not
      nothing
      notnull
      null
      nulls
      of
      offset
      on
      or
      order
      others
      outer
      over
      partition
      plan
      pragma
      preceding
      primary
      query
      raise
      range
      recursive
      references
      regexp
      reindex
      release
      rename
      replace
      restrict
      returning
      right
      rollback
      row
      rows
      savepoint
      select
      set
      table
      temp
      temporary
      then
      ties
      to
      transaction
      trigger
      unbounded
      union
      unique
      update
      using
      vacuum
      values
      view
      virtual
      when
      where
      window
      with
      without
    ]

    def self.escape_identifier(identifier)
      if SQLITE_KEYWORDS.include?(identifier)
        %Q("#{identifier}")
      else
        identifier
      end
    end

    def self.to_singular_classname(snake_case_string)
      snake_case_string.downcase.singularize.camelize
    end

    def self.to_const_name(name)
      name.parameterize.underscore.upcase
    end

    def self.format_ruby_files(path)
      glob_pattern = File.join(path, "*.rb")

      system(
        "bundle",
        "exec",
        "stree",
        "write",
        glob_pattern,
        exception: true,
        out: File::NULL,
        err: File::NULL,
      )
    rescue StandardError
      raise "Failed to run `bundle exec stree write '#{glob_pattern}'`"
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

    def self.plugin_manifest(database: :intermediate_db)
      database.to_sym # keep keyword API stable; manifest is shared for all schema outputs
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

    def self.scaffold(table_name, database: :intermediate_db)
      ensure_ready!(database:)
      DSL::Scaffolder.new(self, table_name, database:).scaffold!
    end

    # --- Lifecycle Methods ---

    def self.ensure_ready!(database: :intermediate_db)
      db_key = database.to_sym
      path = config_path(database)

      unless File.directory?(path)
        available = available_databases.join(", ")
        raise ConfigError, I18n.t("schema.unknown_database", name: database, available:)
      end

      return if @ready == db_key

      reset!
      begin
        DSL::Loader.new(path).load!
        registry.freeze!
        @ready = db_key
      rescue StandardError
        # Avoid keeping partially loaded DSL state after a loader failure.
        reset!
        raise
      end

      manifest = plugin_manifest(database:)
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
          puts I18n.t("schema.detect_plugins.auto_failed", error: e.message)
        end
      end
    end

    def self.config_path(database = :intermediate_db)
      File.join(Migrations.root_path, "config", "schema", database.to_s)
    end

    def self.manifest_path
      File.join(Migrations.root_path, "config", "schema", "plugin_manifest.yml")
    end

    def self.available_databases
      dir = File.join(Migrations.root_path, "config", "schema")
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
    private_class_method :registry
  end
end
