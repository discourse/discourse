# frozen_string_literal: true

DiscourseAutomation::Scriptable::USER_GROUP_MEMBERSHIP_THROUGH_BADGE =
  "user_group_membership_through_badge"
DiscourseAutomation::Scriptable::USER_GROUP_MEMBERSHIP_THROUGH_BADGE_BULK_MODIFY_START_COUNT = 1000

DiscourseAutomation::Scriptable.add(
  DiscourseAutomation::Scriptable::USER_GROUP_MEMBERSHIP_THROUGH_BADGE,
) do
  version 1

  field :badge_name, component: :text, required: true
  field :group, component: :group, required: true
  field :remove_members_without_badge, component: :boolean

  triggerables %i[recurring user_first_logged_in]

  script do |context, fields|
    badge_name = fields.dig("badge_name", "value").strip
    group_id = fields.dig("group", "value")
    remove_members_without_badge = fields.dig("remove_members_without_badge", "value")
    current_user = context["user"]
    bulk_modify_start_count =
      DiscourseAutomation::Scriptable::USER_GROUP_MEMBERSHIP_THROUGH_BADGE_BULK_MODIFY_START_COUNT

    badge = Badge.find_by(name: badge_name)
    unless badge
      Rails.logger.warn("[discourse-automation] Couldn’t find badge with name #{badge_name}")
      next
    end

    group = Group.find_by(id: group_id)
    unless group
      Rails.logger.warn("[discourse-automation] Couldn’t find group with id #{group_id}")
      next
    end

    query_options = { group_id: group.id, badge_id: badge.id }

    # IDs of users who currently have badge but not members of target group
    user_ids_to_add_query = +<<~SQL
      SELECT u.id AS user_id
      FROM users u
      JOIN user_badges ub ON u.id = ub.user_id
      LEFT JOIN group_users gu ON u.id = gu.user_id AND gu.group_id = :group_id
      WHERE ub.badge_id = :badge_id AND gu.user_id IS NULL
    SQL

    if current_user
      user_ids_to_add_query << " AND u.id = :user_id"
      query_options[:user_id] = current_user.id
    end

    user_ids_to_add = DB.query_single(user_ids_to_add_query, query_options)

    if user_ids_to_add.count < bulk_modify_start_count
      User
        .where(id: user_ids_to_add)
        .each do |user|
          group.add(user)
          GroupActionLogger.new(Discourse.system_user, group).log_add_user_to_group(user)
        end
    else
      group.bulk_add(user_ids_to_add)
    end

    next unless remove_members_without_badge

    # IDs of users who are currently target group members without the badge
    user_ids_to_remove_query = +<<~SQL
      SELECT u.id AS user_id
      FROM users u
      JOIN group_users gu ON u.id = gu.user_id
      LEFT JOIN user_badges ub ON u.id = ub.user_id AND ub.badge_id = :badge_id
      WHERE gu.group_id = :group_id AND ub.user_id IS NULL
    SQL

    if current_user
      user_ids_to_remove_query << " AND u.id = :user_id"
      query_options[:user_id] ||= current_user.id
    end

    user_ids_to_remove = DB.query_single(user_ids_to_remove_query, query_options)

    if user_ids_to_remove.count < bulk_modify_start_count
      User
        .where(id: user_ids_to_remove)
        .each do |user|
          group.remove(user)
          GroupActionLogger.new(Discourse.system_user, group).log_remove_user_from_group(user)
        end
    else
      group.bulk_remove(user_ids_to_remove)
    end
  end
end
