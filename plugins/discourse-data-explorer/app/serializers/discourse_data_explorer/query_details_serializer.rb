# frozen_string_literal: true

module ::DiscourseDataExplorer
  class QueryDetailsSerializer < QuerySerializer
    attributes :sql, :param_info, :created_at, :hidden

    def param_info
      object&.params&.uniq { |p| p.identifier }&.map(&:to_hash)
    end
  end
end
