# frozen_string_literal: true

module DiscourseDataExplorer
  module Adapters
    class CachedResults
      class RelatedResults < JsonApiKit::Adapter::RelatedRecords
        def scope = Selection.new(queries: owners, params: {})

        private

        def pair(records)
          records
            .group_by(&:query_id)
            .then { |results| owners.to_h { [it, results.fetch(it.id.to_s, [])] } }
        end
      end
    end
  end
end
