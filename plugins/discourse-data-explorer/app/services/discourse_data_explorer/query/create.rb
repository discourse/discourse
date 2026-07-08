# frozen_string_literal: true

module DiscourseDataExplorer
  class Query::Create
    include Service::Base

    # Mirrors the data_explorer_queries.sql column default the legacy path
    # relies on when no SQL is provided.
    DEFAULT_SQL = "SELECT 1"

    params do
      attribute :name, :string
      attribute :description, :string
      attribute :query, :string
      attribute :group_ids, :array, default: []

      validates :name, presence: true

      before_validation do
        self.description = description.presence
        self.query = DEFAULT_SQL if query.blank?
        self.group_ids = Array(group_ids).reject(&:blank?).map(&:to_i).uniq
      end
    end

    policy :can_create_query
    model :groups, optional: true
    policy :all_requested_groups_exist

    transaction do
      model :query, :create_query
      step :bind_query_to_groups
    end

    private

    def can_create_query(guardian:)
      guardian.is_admin?
    end

    def fetch_groups(params:)
      Group.where(id: params.group_ids)
    end

    def all_requested_groups_exist(params:, groups:)
      groups.size == params.group_ids.size
    end

    def create_query(params:, guardian:)
      Query.create(
        name: params.name,
        description: params.description,
        sql: params.query,
        user_id: guardian.user.id,
        last_run_at: Time.zone.now,
      )
    end

    def bind_query_to_groups(query:, groups:)
      query.groups = groups.to_a
    end
  end
end
