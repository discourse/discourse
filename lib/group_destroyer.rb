# frozen_string_literal: true

class GroupDestroyer
  # Deleting a group is admin-only. The HTTP route gets that from
  # AdminConstraint, so the check lives here for callers without a route.
  def self.ensure_allowed!(guardian, group)
    raise Discourse::InvalidAccess if !guardian.is_admin?
    GroupMutations.ensure_not_automatic!(group)
  end

  def self.destroy(guardian, group)
    ensure_allowed!(guardian, group)

    Group.transaction do
      StaffActionLogger.new(guardian.user).log_group_deletion(group)
      group.destroy!
    end

    group
  end
end
