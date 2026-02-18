# frozen_string_literal: true

require "prism"

module Migrations::Database::Schema::DSL
  class IgnoredFileEditor
    def initialize(config_path)
      @ignored_path = File.join(config_path, "ignored.rb")
    end

    def add_table(table_name, reason: nil)
      table_name = table_name.to_s

      unless /\A[a-z0-9_]+\z/.match?(table_name)
        raise(
          Migrations::Database::Schema::ConfigError,
          "Invalid table name '#{table_name}'. Use lowercase letters, numbers, and underscores.",
        )
      end

      unless File.exist?(@ignored_path)
        raise Migrations::Database::Schema::ConfigError, "ignored.rb not found at #{@ignored_path}"
      end

      content = File.read(@ignored_path)
      block_data = parse_ignored_block(content)

      if block_data[:table_names].include?(table_name)
        raise Migrations::Database::Schema::ConfigError, "Table #{table_name} is already ignored"
      end

      entry =
        reason.present? ? "  table :#{table_name}, #{reason.inspect}\n" : "  table :#{table_name}\n"
      content.insert(block_data[:end_offset], entry)
      File.write(@ignored_path, content)
    end

    private

    def parse_ignored_block(content)
      result = Prism.parse(content)
      unless result.success?
        details = result.errors.map(&:message).join(", ")
        raise Migrations::Database::Schema::ConfigError,
              "Could not parse #{@ignored_path}: #{details}"
      end

      ignored_call = find_ignored_call(result.value)
      if ignored_call.nil?
        raise Migrations::Database::Schema::ConfigError,
              "Could not find `Migrations::Database::Schema.ignored do ... end` in #{@ignored_path}"
      end

      {
        end_offset: ignored_call.block.closing_loc.start_offset,
        table_names: extract_table_names(ignored_call.block),
      }
    end

    def find_ignored_call(node)
      return node if node.is_a?(Prism::CallNode) && ignored_call_with_block?(node)

      node.compact_child_nodes.each do |child|
        found = find_ignored_call(child)
        return found if found
      end

      nil
    end

    def ignored_call_with_block?(node)
      return false unless node.message.to_s == "ignored"
      return false unless node.block

      receiver = node.receiver
      return false unless receiver.is_a?(Prism::ConstantPathNode)

      receiver.full_name.to_s.sub(/\A::/, "") == "Migrations::Database::Schema"
    end

    def extract_table_names(block_node)
      names = Set.new
      body = block_node&.body
      return names unless body.is_a?(Prism::StatementsNode)

      body.body.each do |statement|
        next unless statement.is_a?(Prism::CallNode)

        message = statement.message.to_s
        next unless message == "table" || message == "tables"

        args = statement.arguments&.arguments || []
        args.each { |arg| names << arg.unescaped if arg.is_a?(Prism::SymbolNode) }
      end

      names
    end
  end
end
