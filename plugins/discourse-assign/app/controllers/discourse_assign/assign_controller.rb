# frozen_string_literal: true

module DiscourseAssign
  class AssignController < ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login

    SEARCH_LIMIT = 6

    before_action :ensure_logged_in, :ensure_assign_allowed

    def suggestions
      target = optional_assignable_target

      render json: {
               suggestions: serialize_users([current_user, *recent_assignees(target)]),
               groups: serialize_groups(searchable_groups(target)),
             }
    end

    def search
      term = params.require(:term).strip
      raise Discourse::InvalidParameters.new(:term) if term.blank?
      target = optional_assignable_target

      users =
        UserSearch.new(
          term,
          searching_user: current_user,
          user_ids: assignable_user_ids(target),
          limit: SEARCH_LIMIT,
        ).search
      groups = Group.search_groups(term, groups: searchable_groups(target), sort: :auto)

      render json: {
               users: serialize_users(users),
               groups: serialize_groups(groups.limit(SEARCH_LIMIT)),
             }
    end

    def unassign
      Assigner.new(assignable_target_from_params, current_user).unassign

      render json: success_json
    end

    def assign
      username = params.permit(:username)["username"].presence
      group_name = params.permit(:group_name)["group_name"].presence
      note = params.permit(:note)["note"].presence
      status = params.permit(:status)["status"].presence
      should_notify = params.permit(:should_notify)["should_notify"]
      should_notify = (should_notify.present? ? should_notify.to_s == "true" : true)

      target = target_from_params

      assign_to = DiscourseAssign::AssigneeResolver.resolve!(guardian, username:, group_name:)

      assign = Assigner.new(target, current_user).assign(assign_to, note:, status:, should_notify:)

      if assign[:success]
        render json: success_json
      else
        render json: {
                 error: Assigner.failure_message(assign[:reason], assign_to),
               },
               status: :bad_request
      end
    end

    def assigned
      raise Discourse::InvalidAccess unless current_user&.admin?

      offset = (params[:offset] || 0).to_i
      limit = (params[:limit] || 100).to_i

      topics =
        Topic
          .includes(:tags)
          .includes(:user)
          .joins(
            "JOIN assignments a ON a.target_id = topics.id AND a.target_type = 'Topic' AND a.assigned_to_id IS NOT NULL",
          )
          .order("a.assigned_to_id, topics.bumped_at desc")
          .offset(offset)
          .limit(limit)

      Topic.preload_custom_fields(topics, TopicList.preloaded_custom_fields)

      topic_assignments =
        Assignment
          .where(target_id: topics.map(&:id), target_type: "Topic", active: true)
          .pluck(:target_id, :assigned_to_id)
          .to_h

      users =
        User
          .where("users.id IN (?)", topic_assignments.values.uniq)
          .joins("join user_emails on user_emails.user_id = users.id AND user_emails.primary")
          .select(UserLookup.lookup_columns)
          .to_a

      User.preload_custom_fields(users, User.allowed_user_custom_fields(guardian))

      users_map = users.index_by(&:id)

      topics.each do |topic|
        user_id = topic_assignments[topic.id]
        topic.preload_assigned_to(users_map[user_id]) if user_id
      end

      render json: { topics: serialize_data(topics, AssignedTopicSerializer) }
    end

    def group_members
      limit = (params[:limit] || 50).to_i
      offset = params[:offset].to_i

      raise Discourse::InvalidParameters.new(:limit) if limit < 0 || limit > 1000
      raise Discourse::InvalidParameters.new(:offset) if offset < 0
      raise Discourse::NotFound.new if !params[:group_name].present?

      group = Group.find_by(name: params[:group_name])

      guardian.ensure_can_see_group_and_members!(group)
      raise Discourse::InvalidAccess if !guardian.can_assign_globally?

      users_with_assignments_count =
        User
          .joins("LEFT OUTER JOIN group_users g ON g.user_id = users.id")
          .joins(
            "LEFT OUTER JOIN assignments a ON a.assigned_to_id = users.id AND a.assigned_to_type = 'User'",
          )
          .joins("LEFT OUTER JOIN topics t ON t.id = a.target_id AND a.target_type = 'Topic'")
          .where("g.group_id = ? AND users.id > 0 AND t.deleted_at IS NULL", group.id)
          .where("a.assigned_to_id IS NOT NULL AND a.active")
          .order("COUNT(users.id) DESC")
          .group("users.id")
          .select('users.*, COUNT(users.id) as "assignments_count"')
          .limit(limit)
          .offset(offset)

      if params[:filter]
        filter_query = "users.username_lower ILIKE :pattern"
        filter_query = "users.name ILIKE :pattern OR #{filter_query}" if SiteSetting.enable_names?
        users_with_assignments_count =
          users_with_assignments_count.where(filter_query, pattern: "%#{params[:filter]}%")
      end
      group_assignments_count = Assignment.active_for_group(group).count
      users_assignments_count =
        users_with_assignments_count.reduce(0) do |sum, assignment|
          sum + assignment.assignments_count
        end

      render json: {
               members: serialize_data(users_with_assignments_count, GroupUserAssignedSerializer),
               assignment_count: users_assignments_count + group_assignments_count,
               group_assignment_count: group_assignments_count,
             }
    end

    private

    def ensure_assign_allowed
      raise Discourse::InvalidAccess.new unless current_user.can_assign?
    end

    def assignable_user_ids(target)
      DiscourseAssign::AssignmentPermissions.assignable_user_ids(target, assigner: current_user)
    end

    def searchable_groups(target)
      groups =
        Group.visible_groups(current_user).where(
          id:
            DiscourseAssign::AssignmentPermissions.assignable_groups(
              target,
              assigner: current_user,
            ).select(:id),
        )
      DiscoursePluginRegistry.apply_modifier(:groups_for_users_search, groups)
    end

    def serialize_users(users)
      ActiveModel::ArraySerializer.new(
        users,
        scope: guardian,
        each_serializer: FoundUserSerializer,
        include_status: true,
      )
    end

    def serialize_groups(groups)
      groups.pluck(:name, :full_name).map { |name, full_name| { name:, full_name: } }
    end

    def recent_assignees(target)
      User
        .where.not(id: current_user.id)
        .where(id: assignable_user_ids(target))
        .joins(<<~SQL)
          JOIN(
            SELECT assigned_to_id user_id, MAX(created_at) last_assigned
            FROM assignments
            WHERE assignments.assigned_to_type = 'User'
            GROUP BY assigned_to_id
            HAVING COUNT(*) < #{SiteSetting.max_assigned_topics}
          ) as X ON X.user_id = users.id
        SQL
        .joins(<<~SQL)
          LEFT JOIN(
            SELECT DISTINCT ON (user_id) name, user_id
            FROM user_custom_fields
            WHERE name = '#{DiscourseCalendar::HOLIDAY_CUSTOM_FIELD}'
          ) AS ucf on ucf.user_id = users.id
        SQL
        .where("ucf.name is NULL")
        .order("X.last_assigned DESC")
        .limit(5)
    end

    def target_from_params
      target_type = params.require(:target_type)
      raise Discourse::NotFound if !Assignment.valid_type?(target_type)

      target = target_type.constantize.find_by(id: params.require(:target_id))
      raise Discourse::NotFound if target.blank? || !guardian.can_see?(target)

      target
    end

    def assignable_target_from_params
      target_from_params.tap { |target| guardian.ensure_can_assign!(target) }
    end

    def optional_assignable_target
      return if params[:target_id].blank? && params[:target_type].blank?

      assignable_target_from_params
    end
  end
end
