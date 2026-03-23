# frozen_string_literal: true

class GroupManager
  def initialize(acting_user, group)
    @acting_user = acting_user
    @group = group
  end

  def add(user, notify: false, automatic: false, subject: nil, log: true)
    return false if user.nil?

    added_user_ids = @group.bulk_add([user.id], automatic:)
    return false if added_user_ids.empty?

    logger.bulk_log_add_user_to_group([user], subject) if log
    @group.notify_added_to_group(user) if notify

    true
  end

  def bulk_add(user_ids, automatic: false, subject: nil, log: true)
    return [] if user_ids.blank?

    added_user_ids = @group.bulk_add(user_ids, automatic:)

    if added_user_ids.present? && log
      added_users = User.where(id: added_user_ids).to_a
      logger.bulk_log_add_user_to_group(added_users, subject)
    end

    added_user_ids
  end

  def remove(user, subject: nil, log: true)
    return false if user.nil?

    removed_user_ids = @group.bulk_remove([user.id])
    return false if removed_user_ids.empty?

    logger.bulk_log_remove_user_from_group([user], subject) if log

    true
  end

  def bulk_remove(user_ids, subject: nil, log: true)
    return [] if user_ids.blank?

    removed_user_ids = @group.bulk_remove(user_ids)

    if removed_user_ids.present? && log
      removed_users = User.where(id: removed_user_ids).to_a
      logger.bulk_log_remove_user_from_group(removed_users, subject)
    end

    removed_user_ids
  end

  private

  def logger
    @logger ||= GroupActionLogger.new(@acting_user, @group)
  end
end
