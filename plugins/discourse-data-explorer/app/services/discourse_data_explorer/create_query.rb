# frozen_string_literal: true

module DiscourseDataExplorer
  class CreateQuery
    include Service::Base

    policy :can_create_query

    params(from_resource: QueryResource, only: %i[name description sql tags group_ids]) do
      attribute :tags, :array, element_type: ActiveModel::Type.lookup(:string)

      validates :name, presence: true

      def query_attributes = slice(:name, :description, :sql).compact_blank

      def requested_group_ids = Array.wrap(group_ids).uniq
    end

    model :groups, optional: true
    policy :requested_groups_exist

    try ActiveRecord::RecordInvalid do
      transaction do
        model :query, :create_query
        only_if(:has_tags?) { step :sync_tags }
      end
    end

    private

    def can_create_query(guardian:)
      guardian.is_admin?
    end

    def fetch_groups(params:)
      Group.where(id: params.requested_group_ids).to_a
    end

    def requested_groups_exist(params:, groups:)
      groups.size == params.requested_group_ids.size
    end

    def create_query(params:, guardian:, groups:)
      Query.create(
        **params.query_attributes,
        user: guardian.user,
        groups:,
        last_run_at: Time.current,
      )
    end

    def has_tags?(params:)
      params.tags.present?
    end

    def sync_tags(query:, params:)
      QueryTag.sync!(query:, names: params.tags)
    end
  end
end
