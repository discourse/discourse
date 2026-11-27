# frozen_string_literal: true

module DiscourseDataExplorer
  class ReplaceQueryGroups
    include Service::Base

    policy :can_replace_query_groups
    model :query

    params(from_resource: QueryResource, only: %i[group_ids]) do
      validate { errors.add(:group_ids, :blank) if group_ids.nil? }

      def requested_group_ids = Array.wrap(group_ids).uniq
    end

    model :groups, optional: true
    policy :requested_groups_exist
    transaction { step :replace_group_access }

    private

    def can_replace_query_groups(guardian:)
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

    def replace_group_access(query:, groups:)
      query.groups = groups
    end
  end
end
