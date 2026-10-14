# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      module Diff
        # Row-by-row diff of one table, keyed by the primary key, or as a
        # multiset of whole rows when there is none.
        class TableDiff
          attr_reader :table,
                      :key_columns,
                      :columns,
                      :added,
                      :removed,
                      :changed,
                      :ignored_only,
                      :same

          def initialize(table, columns, key_columns, ignore_columns, where, redact)
            @table = table
            @where = where
            @redact = redact
            @columns = columns
            @key_columns = key_columns
            @key_indexes = key_columns.map { |c| columns.index(c) }
            @ignore_indexes = ignore_columns.filter_map { |c| columns.index(c) }
            @added = []
            @removed = []
            @changed = []
            @ignored_only = 0
            @same = 0
          end

          def keyed?
            @key_indexes.any?
          end

          def run(before_db, after_db, schema)
            if keyed?
              run_keyed(before_db, after_db, schema)
            else
              run_unkeyed(before_db, after_db, schema)
            end
            self
          end

          def row_hash(row)
            columns.zip(row).to_h
          end

          def key_of(row)
            @key_indexes.map { |i| row[i] }
          end

          private

          def run_keyed(before_db, after_db, schema)
            before_rows = {}
            before_db.each_row(schema, table, columns, @where, @redact) do |row|
              before_rows[key_of(row)] = row
            end

            after_db.each_row(schema, table, columns, @where, @redact) do |row|
              key = key_of(row)
              before = before_rows.delete(key)
              if before.nil?
                @added << row
              elsif before == row
                @same += 1
              else
                compare(key, before, row)
              end
            end

            @removed = before_rows.values
          end

          def compare(key, before, after)
            diffs = {}
            meaningful = false
            columns.each_with_index do |col, i|
              next if before[i] == after[i]
              diffs[col] = [before[i], after[i]]
              meaningful ||= !@ignore_indexes.include?(i)
            end

            if meaningful
              @changed << { key:, before:, after:, diffs: }
            else
              @ignored_only += 1
            end
          end

          def run_unkeyed(before_db, after_db, schema)
            counts = Hash.new(0)
            before_db.each_row(schema, table, columns, @where, @redact) { |row| counts[row] += 1 }

            after_db.each_row(schema, table, columns, @where, @redact) do |row|
              if counts[row] > 0
                counts[row] -= 1
                @same += 1
              else
                @added << row
              end
            end

            counts.each { |row, n| n.times { @removed << row } }
          end
        end
      end
    end
  end
end
