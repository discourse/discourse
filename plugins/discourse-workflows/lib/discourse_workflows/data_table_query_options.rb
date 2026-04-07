# frozen_string_literal: true

module DiscourseWorkflows
  DataTableQueryOptions =
    Data.define(:normalized_filter, :limit, :offset, :sort_by, :sort_direction) do
      def initialize(
        normalized_filter: nil,
        limit: nil,
        offset: nil,
        sort_by: nil,
        sort_direction: nil
      )
        super
      end
    end
end
