# frozen_string_literal: true

require "json"

module Migrations
  module Importer
    module Customizations
      module Diff
        # Diffs two databases table by table:
        #   1. Every table present in both gets a cheap fingerprint. Identical
        #      tables are done at that point.
        #   2. Tables whose fingerprint differs are diffed row by row.
        #   3. Upload ids referenced by added/changed rows are resolved against
        #      the "after" database so the report shows which files need to travel.
        class Runner
          attr_reader :report, :diffs, :selected_count, :upload_ids

          def initialize(
            before:,
            after:,
            schema: Defaults::SCHEMA,
            only: [],
            skip: [],
            include: [],
            default_skips: true,
            row_filters: {},
            ignore_columns: Defaults::IGNORE_COLUMNS,
            max_rows: Defaults::MAX_ROWS,
            redactor: nil,
            warnings: $stderr
          )
            @before_conninfo = before
            @after_conninfo = after
            @schema = schema
            @only = only
            @skip = skip
            @include = include
            @default_skips = default_skips
            @row_filters = Defaults::ROW_FILTERS.merge(row_filters)
            @ignore_columns = ignore_columns
            @max_rows = max_rows
            @redactor = redactor
            @warnings = warnings
          end

          # @return [Runner] self, with `report` and `diffs` filled
          def run
            @redactor ||=
              Redactor.new(secret_setting_names: Secrets.flagged_setting_names(warnings: @warnings))
            @warnings.puts "redacting #{@redactor.secret_setting_count} settings flagged as secret, " \
                             "plus name and column patterns"

            before_db = Database.new(@before_conninfo)
            after_db = Database.new(@after_conninfo)
            begin
              compare(before_db, after_db)
            ensure
              before_db.close
              after_db.close
            end
            self
          end

          def write_json(path)
            File.write(path, JSON.pretty_generate(@report))
          end

          private

          def compare(before_db, after_db)
            before_tables = before_db.tables(@schema)
            after_tables = after_db.tables(@schema)
            common = before_tables & after_tables
            selected = select_tables(common)

            @report = {
              only_in_before: before_tables - after_tables,
              only_in_after: after_tables - before_tables,
              skipped: {
              },
              identical: [],
              too_large: {
              },
              schema_mismatch: {
              },
              tables: {
              },
            }
            @diffs = []
            warn_about_tables(common)

            upload_ids = Set.new
            selected.each do |table|
              diff = diff_table(before_db, after_db, table)
              next if diff.nil?

              (diff.added + diff.changed.map { |c| c[:after] }).each do |row|
                upload_ids.merge(UploadRefs.call(table, diff.row_hash(row)))
              end
            end

            if @only.empty?
              (common - selected).each do |table|
                @report[:skipped][table] = {
                  before: before_db.count(@schema, table),
                  after: after_db.count(@schema, table),
                }
              end
            end

            @report[:uploads] = after_db.uploads(upload_ids.to_a).transform_keys(&:to_s)
            @selected_count = selected.size
            @upload_ids = upload_ids
          end

          def select_tables(common)
            skips = Set.new(@skip)
            skips.merge(Defaults::SKIPS) if @default_skips
            skips.subtract(@include)
            @only.empty? ? common.reject { |t| skips.include?(t) } : common & @only
          end

          def warn_about_tables(common)
            missing_only = @only - common
            if @report[:only_in_before].any?
              @warnings.puts "only in before: #{@report[:only_in_before].join(", ")}"
            end
            if @report[:only_in_after].any?
              @warnings.puts "only in after:  #{@report[:only_in_after].join(", ")}"
            end
            @warnings.puts "requested but missing: #{missing_only.join(", ")}" if missing_only.any?
          end

          def diff_table(before_db, after_db, table)
            before_cols = before_db.columns(@schema, table)
            after_cols = after_db.columns(@schema, table)
            columns = before_cols & after_cols
            if before_cols != after_cols
              @report[:schema_mismatch][table] = {
                only_in_before: before_cols - after_cols,
                only_in_after: after_cols - before_cols,
              }
            end

            where = @row_filters[table]
            before_count, before_md5 = before_db.fingerprint(@schema, table, columns, where)
            after_count, after_md5 = after_db.fingerprint(@schema, table, columns, where)

            if before_md5 == after_md5
              @report[:identical] << table
              return
            end

            if [before_count, after_count].max > @max_rows
              @report[:too_large][table] = { before: before_count, after: after_count }
              return
            end

            key = after_db.primary_key(@schema, table) & columns
            diff =
              TableDiff.new(
                table,
                columns,
                key,
                @ignore_columns,
                where,
                @redactor.for(table, columns),
              ).run(before_db, after_db, @schema)
            @diffs << diff

            @report[:tables][table] = {
              key:,
              where:,
              before_count:,
              after_count:,
              added: diff.added.map { |r| diff.row_hash(r) },
              removed: diff.removed.map { |r| diff.row_hash(r) },
              changed:
                diff.changed.map do |c|
                  { key: c[:key], diffs: c[:diffs], after: diff.row_hash(c[:after]) }
                end,
              ignored_columns_only: diff.ignored_only,
            }
            diff
          end
        end
      end
    end
  end
end
