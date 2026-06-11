# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryResource < ApplicationResource
    self.model = DiscourseDataExplorer::Query
    self.type = :queries

    belongs_to :user, resource: UserResource
    many_to_many :groups, resource: GroupResource, foreign_key: { query_groups: :query_id }

    attribute :name, :string
    attribute :description, :string
    attribute :sql, :string
    attribute :hidden, :boolean
    attribute :last_run_at, :datetime
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    # Persisted queries only — this brackets off the negative-ID virtual
    # "default" queries, which live in code (Queries.default), not the table.
    def base_scope
      DiscourseDataExplorer::Query.where("data_explorer_queries.id > 0")
    end
  end
end
