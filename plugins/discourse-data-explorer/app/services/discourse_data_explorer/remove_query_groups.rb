# frozen_string_literal: true

module DiscourseDataExplorer
  class RemoveQueryGroups
    include Service::Base

    policy :can_remove_query_groups
    model :query

    params(from_resource: QueryResource, only: %i[group_ids]) do
      validate { errors.add(:group_ids, :blank) if group_ids.nil? }

      def requested_group_ids = Array.wrap(group_ids).uniq
    end

    step :revoke_group_access

    private

    def can_remove_query_groups(guardian:)
      guardian.is_admin?
    end

    def fetch_query(params:)
      Query.visible.find_by(id: params.id)
    end

    def revoke_group_access(query:, params:)
      return if params.requested_group_ids.empty?

      query.query_groups.where(group_id: params.requested_group_ids).delete_all
    end
  end
end
