# frozen_string_literal: true

DiscourseAutomation::Scriptable.add(
  DiscourseAutomation::Scripts::GROUP_CATEGORY_NOTIFICATION_DEFAULT,
) do
  version 1

  field :group, component: :group
  field :notification_level, component: :category_notification_level
  field :update_existing_members, component: :boolean

  triggerables %i[category_created_edited]

  script do |context, fields|
    category_id = context["category"].id
    group_id = fields.dig("group", "value")
    notification_level = fields.dig("notification_level", "value")

    unless group = Group.find_by(id: group_id)
      Rails.logger.warn "[discourse-automation] Couldn’t find group with id #{group_id}"
      next
    end

    GroupCategoryNotificationDefault
      .find_or_initialize_by(group_id: group_id, category_id: category_id)
      .tap do |gc|
        gc.notification_level = notification_level
        gc.save!
      end

    if fields.dig("update_existing_members", "value")
      group
        .users
        .select(:id, :user_id)
        .find_in_batches do |batch|
          user_ids = batch.pluck(:user_id)

          category_users = []
          existing_users =
            CategoryUser.where(category_id: category_id, user_id: user_ids).where(
              "notification_level IS NOT NULL",
            )
          skip_user_ids = existing_users.pluck(:user_id)

          batch.each do |group_user|
            next if skip_user_ids.include?(group_user.user_id)
            category_users << {
              category_id: category_id,
              user_id: group_user.user_id,
              notification_level: notification_level,
            }
          end

          next if category_users.blank?

          CategoryUser.insert_all!(category_users)
        end
    end
  end
end
