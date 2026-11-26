# frozen_string_literal: true
module DiscourseDataExplorer
  class ResultFormatConverter
    def self.convert(file_type, result, opts = {})
      new(result, opts).send("to_#{file_type}")
    end

    def initialize(result, opts)
      @result = result
      @opts = opts
    end

    private

    attr_reader :result
    attr_reader :opts

    def pg_result
      @pg_result ||= @result[:pg_result]
    end

    def cols
      @cols ||= pg_result.fields
    end

    def to_csv
      require "csv"
      CSV.generate(+Encodings::BOM) do |csv|
        csv << cols
        pg_result.values.each { |row| csv << row }
      end
    end

    def json_response(rows)
      json = {
        success: true,
        errors: [],
        duration: (result[:duration_secs].to_f * 1000).round(1),
        result_count: rows.length,
        params: opts[:query_params],
        columns: cols,
        default_limit: SiteSetting.data_explorer_query_result_limit,
        rows:,
      }
      json[:explain] = result[:explain] if opts[:explain]
      json
    end

    def to_json
      return json_response(pg_result.values) if opts[:download]

      guardian = Guardian.new(opts[:current_user])
      relations, colrender, hidden = DataExplorer.add_extra_data(pg_result, guardian:)
      json_response(pg_result.values).merge!(relations:, colrender:, hidden_relations: hidden)
    end

    def to_typed_json
      limit = opts.fetch(:limit)
      pg_result.map_types!(PG::TypeMapAllStrings.new)
      json = json_response(pg_result.each_row.take(limit))
      json[:column_schema] = column_schema
      json[:truncated] = pg_result.ntuples > limit if limit.positive?
      json
    end

    def column_schema
      return [] if cols.empty?

      oids = cols.each_index.map { |index| pg_result.ftype(index) }
      modifiers = cols.each_index.map { |index| pg_result.fmod(index) }
      types = DB.query(<<~SQL, oids:, modifiers:)
        SELECT pg_type.typname, pg_catalog.format_type(fields.oid, fields.modifier) AS formatted_type
        FROM unnest(ARRAY[:oids]::oid[], ARRAY[:modifiers]::integer[])
          WITH ORDINALITY AS fields(oid, modifier, position)
        JOIN pg_catalog.pg_type ON pg_type.oid = fields.oid
        ORDER BY fields.position
      SQL
      cols
        .zip(types)
        .map do |name, type|
          field = { name:, type: type.typname }
          if type.typname == "numeric" &&
               (modifier = type.formatted_type.match(/\Anumeric\((\d+),\s*(-?\d+)\)\z/))
            field.merge!(precision: modifier[1].to_i, scale: modifier[2].to_i)
          end
          field
        end
    end

    #TODO: we can move ResultToMarkdown here
  end
end
