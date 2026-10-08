# frozen_string_literal: true

# Join and leave actions a user performs on their own membership.
class GroupSelfMembership
  def self.join(guardian, group)
    user = acting_user(guardian)
    rate_limit!(user)
    raise Discourse::InvalidAccess if !group.public_admission
    return false if group.users.exists?(id: user.id)

    added_user_ids = GroupManager.new(group).add([user.id])
    GroupActionLogger.new(user, group).bulk_log_add_users_to_group(added_user_ids)
    true
  end

  def self.leave(guardian, group)
    user = acting_user(guardian)
    rate_limit!(user)
    raise Discourse::InvalidAccess if !group.public_exit
    return false if !group.remove(user)

    GroupActionLogger.new(user, group).log_remove_user_from_group(user)
    true
  end

  def self.acting_user(guardian)
    guardian.user or raise Discourse::NotLoggedIn
  end
  private_class_method :acting_user

  def self.rate_limit!(user)
    return if user.staff?
    RateLimiter.new(user, "public_group_membership", 3, 1.minute).performed!
  end
  private_class_method :rate_limit!
end
