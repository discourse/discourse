# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class DbSchema < Tool
        def self.signature
          {
            name: name,
            description: "Will load schema information for specific tables in the database",
            parameters: [
              {
                name: "tables",
                description:
                  "list of tables to load schema information for, comma separated list eg: (users,posts))",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "schema"
        end

        def tables
          parameters[:tables]
        end

        def invoke
          tables_arr = tables.split(",").map(&:strip).reject(&:empty?)
          return { schema_info: "", tables: tables } if tables_arr.empty?

          rows = DB.query(<<~SQL, tables_arr)
            select table_name, column_name, data_type, is_nullable, character_maximum_length
            from information_schema.columns
            where table_schema = 'public'
            and table_name in (?)
            order by table_name, ordinal_position
          SQL

          by_table = rows.group_by(&:table_name)
          missing_tables = tables_arr - by_table.keys

          sections =
            tables_arr.filter_map do |table_name|
              cols = by_table[table_name]
              next unless cols

              lines =
                cols.map do |row|
                  attrs = [simplify_type(row.data_type, row.character_maximum_length)]
                  attrs << "PK" if row.column_name == "id"
                  if (fkey = fkey_target(table_name, row.column_name))
                    attrs << "FK → #{fkey}"
                  end
                  attrs << "null" if row.is_nullable == "YES"
                  "  #{row.column_name} #{attrs.join(", ")}"
                end

              "TABLE #{table_name}\n#{lines.join("\n")}"
            end

          sections << "TABLES NOT FOUND: #{missing_tables.join(", ")}" if missing_tables.any?

          { schema_info: sections.join("\n\n"), tables: tables }
        end

        protected

        def description_args
          { tables: tables }
        end

        private

        def simplify_type(type, max_len)
          case type
          when "character varying"
            max_len ? "varchar(#{max_len})" : "varchar"
          when "timestamp without time zone"
            "timestamp"
          when "double precision"
            "double"
          else
            type
          end
        end

        def fkey_target(table_name, column_name)
          return nil if column_name == "id"
          return nil unless column_name.end_with?("_id")

          if defined?(DiscourseDataExplorer::DataExplorer) &&
               DiscourseDataExplorer::DataExplorer.respond_to?(:fkey_info)
            target = DiscourseDataExplorer::DataExplorer.fkey_info(table_name, column_name)
            return target.to_s if target
          end

          nil
        end
      end
    end
  end
end
