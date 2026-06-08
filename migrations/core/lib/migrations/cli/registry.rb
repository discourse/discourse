# frozen_string_literal: true

module Migrations
  module CLI
    # Central registry of top-level `disco` commands. Each gem requires its
    # `register.rb` at startup, which pushes its commands here. The Samovar
    # command tree is built from this registry just before argv is parsed.
    module Registry
      Entry = Struct.new(:name, :command_class, :description, keyword_init: true)

      def self.entries
        @entries ||= {}
      end

      def self.register(name:, command_class:, description: nil)
        name = name.to_s
        raise "A `disco` command named '#{name}' is already registered" if entries.key?(name)
        entries[name] = Entry.new(name:, command_class:, description:)
      end

      def self.reset!
        @entries = {}
      end

      # Resolves the registered command classes (stored as strings to keep Rails
      # lazy) into a name => Class hash, ordered by registration name.
      def self.command_classes
        entries
          .sort_by { |name, _| name }
          .each_with_object({}) do |(name, entry), hash|
            klass = entry.command_class
            klass = klass.to_s.constantize if klass.is_a?(String) || klass.is_a?(Symbol)
            hash[name] = klass
          end
      end
    end
  end
end
