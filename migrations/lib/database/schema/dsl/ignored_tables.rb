# frozen_string_literal: true

module Migrations::Database::Schema::DSL
  IgnoredEntry = Data.define(:name, :reason)

  IgnoredConfig =
    Data.define(:entries) do
      def table_names
        entries.map(&:name).to_set
      end

      def ignored?(name)
        table_names.include?(name.to_sym)
      end

      def reason_for(name)
        entries.find { |e| e.name == name.to_sym }&.reason
      end
    end

  class IgnoredBuilder
    def initialize
      @entries = []
    end

    def table(name, reason)
      if reason.nil? || reason.strip.empty?
        raise Migrations::Database::Schema::ConfigError,
              "Ignored table :#{name} must have a reason."
      end
      @entries << IgnoredEntry.new(name: name.to_sym, reason:)
    end

    def tables(*names, reason:)
      if reason.nil? || reason.strip.empty?
        raise Migrations::Database::Schema::ConfigError, "Ignored tables must have a reason."
      end
      names.flatten.each { |name| @entries << IgnoredEntry.new(name: name.to_sym, reason:) }
    end

    def build
      IgnoredConfig.new(entries: @entries.freeze)
    end
  end
end
