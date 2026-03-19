# frozen_string_literal: true

module Migrations::Database::Schema::DSL
  IgnoredEntry = Data.define(:name, :reason)
  IgnoredPluginEntry = Data.define(:name, :reason)

  IgnoredConfig =
    Data.define(:entries, :plugin_entries) do
      def table_names
        entries.map(&:name).to_set
      end

      def reason_for(name)
        entries.find { |e| e.name == name.to_s }&.reason
      end

      def ignored_plugin_names
        plugin_entries.map(&:name)
      end

      def plugin_ignored?(name)
        normalized = ::Migrations::Database::Schema::Helpers.normalize_plugin_name(name)
        plugin_entries.any? { |e| e.name == normalized }
      end
    end

  class IgnoredBuilder
    def initialize
      @entries = []
      @plugin_entries = []
      @entry_names = {}
      @plugin_entry_names = {}
    end

    def table(name, reason = nil)
      add_table_entry(name, reason)
    end

    def tables(*names, reason: nil)
      names.flatten.each { |name| add_table_entry(name, reason) }
    end

    def plugin(name, reason)
      if reason.nil? || reason.strip.empty?
        raise Migrations::Database::Schema::ConfigError,
              "Ignored plugin :#{name} must have a reason."
      end

      normalized_name = ::Migrations::Database::Schema::Helpers.normalize_plugin_name(name)
      if @plugin_entry_names.key?(normalized_name)
        raise Migrations::Database::Schema::ConfigError,
              "Ignored plugin :#{normalized_name} is already declared."
      end

      @plugin_entry_names[normalized_name] = true
      @plugin_entries << IgnoredPluginEntry.new(name: normalized_name, reason:)
    end

    def build
      IgnoredConfig.new(entries: @entries.freeze, plugin_entries: @plugin_entries.freeze)
    end

    private

    def add_table_entry(name, reason)
      normalized_name = name.to_s
      if @entry_names.key?(normalized_name)
        raise Migrations::Database::Schema::ConfigError,
              "Ignored table :#{normalized_name} is already declared."
      end

      @entry_names[normalized_name] = true
      @entries << IgnoredEntry.new(name: normalized_name, reason:)
    end
  end
end
