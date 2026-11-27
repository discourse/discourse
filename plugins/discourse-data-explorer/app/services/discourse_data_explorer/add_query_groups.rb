# frozen_string_literal: true

module DiscourseDataExplorer
  class AddQueryGroups
    include Service::Base

    policy :can_add_query_groups
    model :query

    params(from_resource: QueryResource, only: %i[group_ids]) do
      validate { errors.add(:group_ids, :blank) if group_ids.nil? }

      def requested_group_ids = Array.wrap(group_ids).uniq
    end

    model :groups, optional: true
    policy :requested_groups_exist
    step :grant_group_access

    private

    def can_add_query_groups(guardian:)
      guardian.is_admin?
    end

    def fetch_query(params:)
      Query.visible.find_by(id: params.id)
    end

    def fetch_groups(params:)
      Group.where(id: params.requested_group_ids).to_a
    end

    def requested_groups_exist(params:, groups:)
      groups.size == params.requested_group_ids.size
    end

    def grant_group_access(query:, groups:)
      return if groups.empty?

      QueryGroup.insert_all(
        groups.map { { query_id: query.id, group_id: it.id } },
        unique_by: %i[query_id group_id],
      )
    end
  end
end
