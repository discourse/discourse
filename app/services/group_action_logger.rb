# frozen_string_literal: true

class GroupActionLogger
  def initialize(acting_user, group)
    @acting_user = acting_user
    @group = group
  end

  def log_make_user_group_owner(target_user)
    GroupHistory.create!(
      default_params.merge(
        action: GroupHistory.actions[:make_user_group_owner],
        target_user: target_user,
      ),
    )
  end

  def log_remove_user_as_group_owner(target_user)
    GroupHistory.create!(
      default_params.merge(
        action: GroupHistory.actions[:remove_user_as_group_owner],
        target_user: target_user,
      ),
    )
  end

  def log_add_user_to_group(target_user, subject = nil)
    GroupHistory.create!(
      default_params.merge(
        action: GroupHistory.actions[:add_user_to_group],
        target_user: target_user,
        subject: subject,
      ),
    )
  end

  def log_remove_user_from_group(target_user, subject = nil)
    GroupHistory.create!(
      default_params.merge(
        action: GroupHistory.actions[:remove_user_from_group],
        target_user: target_user,
        subject: subject,
      ),
    )
  end

  def bulk_log_add_users_to_group(target_user_ids, subject = nil)
    bulk_log(target_user_ids, :add_user_to_group, subject)
  end

  def bulk_log_remove_users_from_group(target_user_ids, subject = nil)
    bulk_log(target_user_ids, :remove_user_from_group, subject)
  end

  def log_change_group_settings
    @group
      .previous_changes
      .except(*excluded_attributes)
      .each do |attribute_name, value|
        next if value[0].blank? && value[1].blank?

        GroupHistory.create!(
          default_params.merge(
            action: GroupHistory.actions[:change_group_setting],
            subject: attribute_name,
            prev_value: value[0],
            new_value: value[1],
          ),
        )
      end
  end

  def log_group_creation
    @group.group_users.each do |group_user|
      log_make_user_group_owner(group_user.user) if group_user.owner?
      log_add_user_to_group(group_user.user)
    end
  end

  private

  def excluded_attributes
    %i[bio_cooked updated_at created_at user_count]
  end

  def default_params
    { group: @group, acting_user: @acting_user }
  end

  def bulk_log(target_user_ids, action, subject = nil)
    return if target_user_ids.blank?

    now = Time.now
    GroupHistory.insert_all(
      target_user_ids.map do |user_id|
        {
          group_id: @group.id,
          acting_user_id: @acting_user.id,
          target_user_id: user_id,
          action: GroupHistory.actions[action],
          created_at: now,
          updated_at: now,
          subject: subject,
        }
      end,
    )
  end
end
