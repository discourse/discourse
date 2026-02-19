# frozen_string_literal: true

module Migrations::Database::Schema::DSL
  class Registry
    attr_reader :config, :conventions_config, :ignored_tables

    def initialize
      @tables = {}
      @enums = {}
      @config = nil
      @conventions_config = nil
      @ignored_tables = nil
      @frozen = false
    end

    def register_config(config)
      raise_if_frozen!
      if @config
        raise Migrations::Database::Schema::ConfigError,
              "Configuration already registered. Only one `configure` block is allowed."
      end
      @config = config
    end

    def register_conventions(conventions)
      raise_if_frozen!
      if @conventions_config
        raise Migrations::Database::Schema::ConfigError,
              "Conventions already registered. Only one `conventions` block is allowed."
      end
      @conventions_config = conventions
    end

    def register_table(name, table_def)
      raise_if_frozen!
      name = name.to_s
      if @tables.key?(name)
        raise Migrations::Database::Schema::ConfigError, "Table :#{name} is already registered."
      end
      @tables[name] = table_def
    end

    def register_enum(name, enum_def)
      raise_if_frozen!
      name = name.to_s
      if @enums.key?(name)
        raise Migrations::Database::Schema::ConfigError, "Enum :#{name} is already registered."
      end
      @enums[name] = enum_def
    end

    def register_ignored(ignored)
      raise_if_frozen!
      if @ignored_tables
        raise Migrations::Database::Schema::ConfigError,
              "Ignored tables already registered. Only one `ignored` block is allowed."
      end
      @ignored_tables = ignored
    end

    def tables
      @tables.dup.freeze
    end

    def enums
      @enums.dup.freeze
    end

    def table(name)
      @tables[name.to_s]
    end

    def enum(name)
      @enums[name.to_s]
    end

    def freeze!
      @frozen = true
      self
    end

    private

    def raise_if_frozen!
      if @frozen
        raise Migrations::Database::Schema::ConfigError,
              "Registry is frozen. Cannot modify after loading."
      end
    end
  end
end
