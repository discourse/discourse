# frozen_string_literal: true

module DiscourseDataExplorer
  class CachedResultResource < JsonApiKit::Resource
    namespace "data-explorer"
    adapter Adapters::CachedResults

    %i[
      columns
      rows
      params
      cached_at
      duration
      result_count
      default_limit
      relations
      colrender
      hidden_relations
    ].each { |name| attribute(name) { |result| result[name] } }

    filter :params do |selection, value|
      selection.with_params(value)
    end
  end
end
