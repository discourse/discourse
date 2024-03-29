# frozen_string_literal: true

# This script takes the name of a User Custom Field containing a group name.
# On each run, it ensures that each user belongs to the group name given by that UCF (NOTE: group full_name, not name).
#
# In other words, it designates a certain User Custom Field to act as
# a "pointer" to a group that the user should belong to, and adds users as needed.

DiscourseAutomation::Scriptable.add(
  DiscourseAutomation::Scripts::ADD_USER_TO_GROUP_THROUGH_CUSTOM_FIELD,
) do
  field :custom_field_name, component: :custom_field, required: true

  version 1

  triggerables %i[recurring user_first_logged_in]

  script do |trigger, fields|
    custom_field_name = fields.dig("custom_field_name", "value")

    case trigger["kind"]
    when DiscourseAutomation::Triggers::API_CALL, DiscourseAutomation::Triggers::RECURRING
      query =
        DB.query(<<-SQL, prefix: ::User::USER_FIELD_PREFIX, custom_field_name: custom_field_name)
        SELECT u.id as user_id, g.id as group_id
        FROM users u
        JOIN user_custom_fields ucf
          ON u.id = ucf.user_id
          AND ucf.name = CONCAT(:prefix, :custom_field_name)
        JOIN groups g
          on g.full_name ilike ucf.value
        FULL OUTER JOIN group_users gu
          ON gu.user_id = u.id
          AND gu.group_id = g.id
        WHERE gu.id is null
          AND u.active = true
        ORDER BY 1, 2
      SQL

      groups_by_id = {}

      User
        .where(id: query.map(&:user_id))
        .order(:id)
        .zip(query) do |user, query_row|
          group_id = query_row.group_id
          group = groups_by_id[group_id] ||= Group.find(group_id)

          group.add(user)
          GroupActionLogger.new(Discourse.system_user, group).log_add_user_to_group(user)
        end
    when DiscourseAutomation::Triggers::USER_FIRST_LOGGED_IN
      group_name =
        DB.query_single(
          <<-SQL,
          SELECT value
          FROM user_custom_fields ucf
          WHERE ucf.user_id = :user_id AND ucf.name = CONCAT(:prefix, :custom_field_name)
        SQL
          prefix: ::User::USER_FIELD_PREFIX,
          custom_field_name: custom_field_name,
          user_id: trigger["user"].id,
        ).first
      next if !group_name

      group = Group.find_by(full_name: group_name)
      next if !group

      user = trigger["user"]
      group.add(user)
      GroupActionLogger.new(Discourse.system_user, group).log_add_user_to_group(user)
    end
  end
end
