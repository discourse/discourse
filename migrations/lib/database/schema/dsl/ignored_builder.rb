# frozen_string_literal: true

module Migrations::Database::Schema::DSL
  IgnoredEntry = Data.define(:name, :reason)
  IgnoredPluginEntry = Data.define(:name, :reason)

  IgnoredConfig =
    Data.define(:entries, :plugin_entries) do
      def table_names
        entries.map(&:name).to_set
      end

      def ignored?(name)
        table_names.include?(name.to_sym)
      end

      def reason_for(name)
        entries.find { |e| e.name == name.to_sym }&.reason
      end

      def ignored_plugin_names
        plugin_entries.map(&:name)
      end

      def plugin_ignored?(name)
        plugin_entries.any? { |e| e.name == name.to_sym }
      end
    end

  class IgnoredBuilder
    def initialize
      @entries = []
      @plugin_entries = []
    end

    def table(name, reason = nil)
      @entries << IgnoredEntry.new(name: name.to_sym, reason:)
    end

    def tables(*names, reason: nil)
      names.flatten.each { |name| @entries << IgnoredEntry.new(name: name.to_sym, reason:) }
    end

    def plugin(name, reason)
      if reason.nil? || reason.strip.empty?
        raise Migrations::Database::Schema::ConfigError,
              "Ignored plugin :#{name} must have a reason."
      end
      @plugin_entries << IgnoredPluginEntry.new(name: name.to_sym, reason:)
    end

    def build
      IgnoredConfig.new(entries: @entries.freeze, plugin_entries: @plugin_entries.freeze)
    end
  end
end
