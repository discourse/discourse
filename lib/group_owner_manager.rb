# frozen_string_literal: true

class GroupOwnerManager
  def self.add(guardian, group, notify_users: false, **selectors)
    new(guardian, group, **selectors).add(notify_users:)
  end

  def self.remove(guardian, group, **selectors)
    new(guardian, group, **selectors).remove
  end

  def initialize(guardian, group, **selectors)
    @guardian = guardian
    @group = group
    @selectors = selectors
  end

  def add(notify_users: false)
    users = authorized_users
    logger = GroupActionLogger.new(guardian.user, group)
    user_ids = users.map(&:id)
    member_ids = group.group_users.where(user_id: user_ids).pluck(:user_id).to_set

    users.each do |user|
      next if member_ids.include?(user.id)
      group.add(user)
      logger.log_add_user_to_group(user)
    end

    group.group_users.where(user_id: user_ids).update_all(owner: true)
    users.each { |user| logger.log_make_user_group_owner(user) }
    if notify_users && user_ids.present?
      Jobs.enqueue(:notify_users_added_to_group, user_ids:, group_id: group.id, owner: true)
    end

    { usernames: users.map(&:username) }
  end

  def remove
    raise Discourse::InvalidAccess if !guardian.is_staff?
    users = authorized_users
    raise Discourse::InvalidParameters.new(:user_id) if users.empty?
    logger = GroupActionLogger.new(guardian.user, group)

    group.group_users.where(user_id: users.map(&:id)).update_all(owner: false)
    users.each { |user| logger.log_remove_user_as_group_owner(user) }

    { usernames: users.map(&:username) }
  end

  private

  attr_reader :guardian, :group, :selectors

  def authorized_users
    GroupMutations.ensure_not_automatic!(group)
    guardian.ensure_can_edit_group!(group)

    GroupMutations.resolve_users(guardian:, **selectors).to_a
  end
end
