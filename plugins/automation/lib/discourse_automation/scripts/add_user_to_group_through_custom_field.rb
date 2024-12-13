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
    case trigger["kind"]
    when DiscourseAutomation::Triggers::API_CALL, DiscourseAutomation::Triggers::RECURRING
      custom_field_name = "#{::User::USER_FIELD_PREFIX}#{fields.dig("custom_field_name", "value")}"

      # mapping of group full_names to ids for quick lookup
      group_ids_by_name = Group.where.not(full_name: [nil, ""]).pluck(:full_name, :id).to_h

      # find users with the custom field who aren't in their designated group
      User
        .joins(
          "JOIN user_custom_fields ucf ON users.id = ucf.user_id AND ucf.name = '#{custom_field_name}'",
        )
        .where(active: true)
        .where("ucf.value IS NOT NULL AND ucf.value != ''")
        .where(
          "NOT EXISTS ( SELECT 1 FROM group_users gu JOIN groups g ON g.id = gu.group_id WHERE gu.user_id = users.id AND g.full_name = ucf.value)",
        )
        .select("users.id, ucf.value as group_name")
        .find_each do |user|
          next unless group_id = group_ids_by_name[user.group_name]

          group = Group.find(group_id)
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
          custom_field_name: fields.dig("custom_field_name", "value"),
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
