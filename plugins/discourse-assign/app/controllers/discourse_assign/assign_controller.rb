# frozen_string_literal: true

module DiscourseAssign
  class AssignController < ApplicationController
    requires_plugin DiscourseAssign::PLUGIN_NAME
    requires_login
    before_action :ensure_logged_in, :ensure_assign_allowed

    def suggestions
      users = [current_user, *recent_assignees]
      render json: {
               assign_allowed_on_groups:
                 Group.visible_groups(current_user).assign_allowed_groups.pluck(:name),
               assign_allowed_for_groups:
                 Group.visible_groups(current_user).assignable(current_user).pluck(:name),
               suggestions:
                 ActiveModel::ArraySerializer.new(
                   users,
                   scope: guardian,
                   each_serializer: FoundUserSerializer,
                   include_status: true,
                 ),
             }
    end

    def unassign
      target_id = params.require(:target_id)
      target_type = params.require(:target_type)
      raise Discourse::NotFound if !Assignment.valid_type?(target_type)
      target = target_type.constantize.where(id: target_id).first
      raise Discourse::NotFound unless target

      assigner = Assigner.new(target, current_user)
      assigner.unassign

      render json: success_json
    end

    def assign
      target_id = params.require(:target_id)
      target_type = params.require(:target_type)
      username = params.permit(:username)["username"]
      group_name = params.permit(:group_name)["group_name"]
      note = params.permit(:note)["note"].presence
      status = params.permit(:status)["status"].presence
      should_notify = params.permit(:should_notify)["should_notify"]
      should_notify = (should_notify.present? ? should_notify.to_s == "true" : true)

      assign_to =
        (
          if username.present?
            User.find_by(username_lower: username.downcase)
          else
            Group.where("LOWER(name) = ?", group_name.downcase).first
          end
        )

      raise Discourse::NotFound unless assign_to
      raise Discourse::NotFound if !Assignment.valid_type?(target_type)
      target = target_type.constantize.where(id: target_id).first
      raise Discourse::NotFound unless target

      assign =
        Assigner.new(target, current_user).assign(
          assign_to,
          note: note,
          status: status,
          should_notify: should_notify,
        )

      if assign[:success]
        render json: success_json
      else
        render json: translate_failure(assign[:reason], assign_to), status: 400
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

      guardian.ensure_can_see_group_members!(group)

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

      users_with_assignments_count =
        users_with_assignments_count.where(<<~SQL, pattern: "%#{params[:filter]}%") if params[
          users.name ILIKE :pattern OR users.username_lower ILIKE :pattern
        SQL
        :filter
      ]
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

    def translate_failure(reason, assign_to)
      case reason
      when :already_assigned
        { error: I18n.t("discourse_assign.already_assigned", username: assign_to.username) }
      when :forbidden_assign_to
        { error: I18n.t("discourse_assign.forbidden_assign_to", username: assign_to.username) }
      when :forbidden_assignee_not_pm_participant
        {
          error:
            I18n.t(
              "discourse_assign.forbidden_assignee_not_pm_participant",
              username: assign_to.username,
            ),
        }
      when :forbidden_assignee_cant_see_topic
        {
          error:
            I18n.t(
              "discourse_assign.forbidden_assignee_cant_see_topic",
              username: assign_to.username,
            ),
        }
      when :group_already_assigned
        { error: I18n.t("discourse_assign.group_already_assigned", group: assign_to.name) }
      when :forbidden_group_assign_to
        { error: I18n.t("discourse_assign.forbidden_group_assign_to", group: assign_to.name) }
      when :forbidden_group_assignee_not_pm_participant
        {
          error:
            I18n.t(
              "discourse_assign.forbidden_group_assignee_not_pm_participant",
              group: assign_to.name,
            ),
        }
      when :forbidden_group_assignee_cant_see_topic
        {
          error:
            I18n.t(
              "discourse_assign.forbidden_group_assignee_cant_see_topic",
              group: assign_to.name,
            ),
        }
      when :too_many_assigns_for_topic
        {
          error:
            I18n.t(
              "discourse_assign.too_many_assigns_for_topic",
              limit: Assigner::ASSIGNMENTS_PER_TOPIC_LIMIT,
            ),
        }
      else
        max = SiteSetting.max_assigned_topics
        {
          error:
            I18n.t("discourse_assign.too_many_assigns", username: assign_to.username, max: max),
        }
      end
    end

    def ensure_assign_allowed
      raise Discourse::InvalidAccess.new unless current_user.can_assign?
    end

    def recent_assignees
      User
        .where("users.id <> ?", current_user.id)
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
        .assign_allowed
        .order("X.last_assigned DESC")
        .limit(5)
    end
  end
end
