# frozen_string_literal: true

module DiscourseDataExplorer
  # Deliberately minimal — exists to exercise the relationship machinery,
  # not to model Group fully.
  class GroupResource < ApplicationResource
    self.model = ::Group
    self.type = :groups

    attribute :name, :string

    # Required by the many_to_many sideload from QueryResource: Graphiti
    # resolves `include=groups` by querying this resource with
    # filter[query_id]=<parent ids>. Eager-loading query_groups here also
    # feeds the sideload's assign_each (which reads group.query_groups)
    # without N+1.
    filter :query_id, :integer, only: [:eq] do
      eq do |scope, value|
        scope.includes(:query_groups).where(data_explorer_query_groups: { query_id: value })
      end
    end
  end
end
