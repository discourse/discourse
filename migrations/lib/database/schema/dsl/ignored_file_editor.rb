# frozen_string_literal: true

require "prism"

module Migrations::Database::Schema::DSL
  class IgnoredFileEditor
    def initialize(config_path)
      @ignored_path = File.join(config_path, "ignored.rb")
    end

    def add_table(table_name, reason: nil)
      table_name = table_name.to_s

      if !/\A[a-z0-9_]+\z/.match?(table_name)
        raise(
          Migrations::Database::Schema::ConfigError,
          "Invalid table name '#{table_name}'. Use lowercase letters, numbers, and underscores.",
        )
      end

      if !File.exist?(@ignored_path)
        raise Migrations::Database::Schema::ConfigError, "ignored.rb not found at #{@ignored_path}"
      end

      content = File.read(@ignored_path)
      block_data = parse_ignored_block(content)

      if block_data[:table_names].include?(table_name)
        raise Migrations::Database::Schema::ConfigError, "Table #{table_name} is already ignored"
      end

      content =
        if reason.nil? && block_data[:last_tables_call]
          append_to_tables_call(content, block_data[:last_tables_call], table_name)
        else
          insert_standalone_entry(content, block_data[:end_offset], table_name, reason)
        end

      File.write(@ignored_path, content)
      format_file!
    end

    private

    def append_to_tables_call(content, tables_call, table_name)
      all_names = (tables_call[:names] + [table_name]).sort
      replacement = "tables " + all_names.map { |n| ":#{n}" }.join(", ")

      content.byteslice(0, tables_call[:start_offset]) + replacement +
        content.byteslice(tables_call[:end_offset]..)
    end

    def insert_standalone_entry(content, end_offset, table_name, reason)
      entry =
        (
          if reason.present?
            "\n  table :#{table_name}, #{reason.inspect}\n"
          else
            "\n  table :#{table_name}\n"
          end
        )

      content.byteslice(0, end_offset) + entry + content.byteslice(end_offset..)
    end

    def parse_ignored_block(content)
      result = Prism.parse(content)
      if !result.success?
        details = result.errors.map(&:message).join(", ")
        raise Migrations::Database::Schema::ConfigError,
              "Could not parse #{@ignored_path}: #{details}"
      end

      declaration = find_ignored_declaration(result.value)
      if declaration.nil?
        raise Migrations::Database::Schema::ConfigError,
              "Could not find `Migrations::Database::Schema.ignored do ... end` in #{@ignored_path}"
      end

      last_tables = find_last_tables_call(declaration.block)

      {
        end_offset: declaration.block.closing_loc.start_offset,
        table_names: extract_table_names(declaration.block),
        last_tables_call:
          last_tables &&
            {
              start_offset: last_tables.location.start_offset,
              end_offset: last_tables.location.end_offset,
              names: symbol_names_from(last_tables),
            },
      }
    end

    def find_ignored_declaration(node)
      return node if node.is_a?(Prism::CallNode) && ignored_declaration?(node)

      node.compact_child_nodes.each do |child|
        found = find_ignored_declaration(child)
        return found if found
      end

      nil
    end

    def ignored_declaration?(node)
      return false unless node.message.to_s == "ignored"
      return false unless node.block

      receiver = node.receiver
      return false unless receiver.is_a?(Prism::ConstantPathNode)

      receiver.full_name.to_s.sub(/\A::/, "") == "Migrations::Database::Schema"
    end

    def find_last_tables_call(block_node)
      body = block_node&.body
      return nil unless body.is_a?(Prism::StatementsNode)

      body.body.select { |s| s.is_a?(Prism::CallNode) && s.message.to_s == "tables" }.last
    end

    def symbol_names_from(call_node)
      args = call_node.arguments&.arguments || []
      args.filter_map { |arg| arg.unescaped if arg.is_a?(Prism::SymbolNode) }
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

    def format_file!
      Migrations::Database::Schema::Helpers.format_ruby_file(@ignored_path)
    end
  end
end
