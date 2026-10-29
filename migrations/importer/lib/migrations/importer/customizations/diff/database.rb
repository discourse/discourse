# frozen_string_literal: true

require "pg"

module Migrations
  module Importer
    module Customizations
      module Diff
        class Database
          attr_reader :conn

          def self.quote(identifier)
            %("#{identifier.gsub('"', '""')}")
          end

          def initialize(conninfo)
            @conn = PG.connect(conninfo)
          end

          def close
            @conn.close
          end

          def tables(schema)
            conn.exec_params(
              "SELECT table_name FROM information_schema.tables " \
                "WHERE table_schema = $1 AND table_type = 'BASE TABLE' ORDER BY 1",
              [schema],
            ).column_values(0)
          end

          def columns(schema, table)
            conn.exec_params(
              "SELECT column_name FROM information_schema.columns " \
                "WHERE table_schema = $1 AND table_name = $2 ORDER BY ordinal_position",
              [schema, table],
            ).column_values(0)
          end

          def primary_key(schema, table)
            conn.exec_params(
              "SELECT a.attname FROM pg_index i " \
                "JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey) " \
                "WHERE i.indrelid = $1::regclass AND i.indisprimary ORDER BY array_position(i.indkey, a.attnum)",
              ["#{quote(schema)}.#{quote(table)}"],
            ).column_values(0)
          end

          # Cheap and order-independent: count plus md5 over the md5 of each row.
          def fingerprint(schema, table, columns, where)
            row = "ROW(#{columns.map { |c| quote(c) }.join(", ")})::text"
            result =
              conn.exec(
                "SELECT count(*), md5(coalesce(string_agg(h, '' ORDER BY h), '')) " \
                  "FROM (SELECT md5(#{row}) AS h FROM #{qualified(schema, table)}#{where_clause(where)}) s",
              )
            [result[0]["count"].to_i, result[0]["md5"]]
          end

          def count(schema, table)
            conn.exec("SELECT count(*) FROM #{qualified(schema, table)}")[0]["count"].to_i
          end

          # Streams rows in batches through a cursor so large tables don't need to
          # fit in memory on the reading side.
          def each_row(schema, table, columns, where, redact = nil)
            cols = columns.map { |c| quote(c) }.join(", ")
            conn.transaction do
              conn.exec(
                "DECLARE diff_cursor NO SCROLL CURSOR FOR SELECT #{cols} " \
                  "FROM #{qualified(schema, table)}#{where_clause(where)}",
              )
              loop do
                batch = conn.exec("FETCH FORWARD 5000 FROM diff_cursor")
                break if batch.ntuples == 0
                batch.each_row { |row| yield(redact ? redact.call(row) : row) }
              end
              conn.exec("CLOSE diff_cursor")
            end
          end

          def uploads(ids)
            return {} if ids.empty?

            conn
              .exec_params(
                "SELECT id, url, original_filename, filesize, sha1 FROM uploads WHERE id = ANY($1::int[])",
                ["{#{ids.join(",")}}"],
              )
              .index_by { |row| row["id"].to_i }
          end

          private

          def quote(identifier)
            self.class.quote(identifier)
          end

          def qualified(schema, table)
            "#{quote(schema)}.#{quote(table)}"
          end

          def where_clause(where)
            where ? " WHERE #{where}" : ""
          end
        end
      end
    end
  end
end
