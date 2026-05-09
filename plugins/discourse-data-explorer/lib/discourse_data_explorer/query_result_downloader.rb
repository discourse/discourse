# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryResultDownloader
    def self.download(query, raw_params, current_user:, explain: false, limit: nil, format: :json)
      query_params = QueryRunner.parse_params(raw_params)
      opts = { current_user: }
      opts[:explain] = true if explain
      opts[:limit] = limit if limit

      result = DataExplorer.run_query(query, query_params, opts)

      return { error: result[:error] } if result[:error]

      output =
        ResultFormatConverter.convert(format, result, query_params:, explain:, download: true)

      { data: output, format: }
    end
  end
end
