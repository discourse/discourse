# frozen_string_literal: true
module ::DiscourseDataExplorer
  class ResultFormatConverter
    def self.convert(file_type, result, opts = {})
      self.new(result, opts).send("to_#{file_type}")
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
      CSV.generate do |csv|
        csv << cols
        pg_result.values.each { |row| csv << row }
      end
    end

    def to_json
      json = {
        success: true,
        errors: [],
        duration: (result[:duration_secs].to_f * 1000).round(1),
        result_count: pg_result.values.length || 0,
        params: opts[:query_params],
        columns: cols,
        default_limit: SiteSetting.data_explorer_query_result_limit,
      }
      json[:explain] = result[:explain] if opts[:explain]

      if !opts[:download]
        relations, colrender = DataExplorer.add_extra_data(pg_result)
        json[:relations] = relations
        json[:colrender] = colrender
      end

      json[:rows] = pg_result.values

      json
    end

    #TODO: we can move ResultToMarkdown here
  end
end
