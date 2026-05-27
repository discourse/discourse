# frozen_string_literal: true

require "prism"

module Migrations
  module Database
    module Schema
      module DSL
        class IgnoredFileEditor
          def initialize(config_path)
            @ignored_path = File.join(config_path, "ignored.rb")
          end

          def add_table(table_name, reason: nil)
            table_name = table_name.to_s

            if !/\A[a-z0-9_]+\z/.match?(table_name)
              raise(
                ConfigError,
                "Invalid table name '#{table_name}'. Use lowercase letters, numbers, and underscores.",
              )
            end

            if !File.exist?(@ignored_path)
              raise ConfigError, "ignored.rb not found at #{@ignored_path}"
            end

            content = File.read(@ignored_path)
            ignored_block = parse_ignored_block(content)

            if ignored_block[:table_names].include?(table_name)
              raise ConfigError, "Table #{table_name} is already ignored"
            end

            content =
              if reason.nil? && ignored_block[:last_tables_group]
                append_to_tables_group(content, ignored_block[:last_tables_group], table_name)
              else
                insert_standalone_entry(content, ignored_block[:end_offset], table_name, reason)
              end

            File.write(@ignored_path, content)
            format_file!
          end

          private

          def append_to_tables_group(content, tables_group, table_name)
            all_names = (tables_group[:names] + [table_name]).sort
            replacement = "tables " + all_names.map { |n| ":#{n}" }.join(", ")
            replacement += ", #{tables_group[:keyword_source]}" if tables_group[:keyword_source]

            content.byteslice(0, tables_group[:start_offset]) + replacement +
              content.byteslice(tables_group[:end_offset]..)
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
              raise ConfigError, "Could not parse #{@ignored_path}: #{details}"
            end

            declaration = find_ignored_declaration(result.value)
            if declaration.nil?
              raise ConfigError,
                    "Could not find `Migrations::Database::Schema.ignored do ... end` in #{@ignored_path}"
            end

            last_tables = find_last_tables_group(declaration.block)

            {
              end_offset: declaration.block.closing_loc.start_offset,
              table_names: extract_all_table_names(declaration.block),
              last_tables_group:
                last_tables &&
                  {
                    start_offset: last_tables.location.start_offset,
                    end_offset: last_tables.location.end_offset,
                    names: table_names_from(last_tables),
                    keyword_source: trailing_keyword_source(last_tables, content),
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

          def find_last_tables_group(block_node)
            body = block_node&.body
            return nil unless body.is_a?(Prism::StatementsNode)

            body.body.select { |s| s.is_a?(Prism::CallNode) && s.message.to_s == "tables" }.last
          end

          def table_names_from(call_node)
            args = call_node.arguments&.arguments || []
            args.filter_map { |arg| arg.unescaped if arg.is_a?(Prism::SymbolNode) }
          end

          def trailing_keyword_source(call_node, content)
            args = call_node.arguments&.arguments || []
            keyword_hash = args.find { |arg| arg.is_a?(Prism::KeywordHashNode) }
            return nil unless keyword_hash

            content.byteslice(keyword_hash.location.start_offset...keyword_hash.location.end_offset)
          end

          def extract_all_table_names(block_node)
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
            Helpers.format_ruby_file(@ignored_path)
          end
        end
      end
    end
  end
end
