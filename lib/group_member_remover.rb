# frozen_string_literal: true

class GroupMemberRemover
  def self.remove(guardian, group, **selectors)
    new(guardian, group, **selectors).remove
  end

  def initialize(guardian, group, **selectors)
    @guardian = guardian
    @group = group
    @selectors = selectors
  end

  def remove
    guardian.ensure_can_edit!(group)

    users = GroupMutations.resolve_users(guardian:, **selectors)
    if users.empty?
      raise Discourse::InvalidParameters.new("user_ids or usernames or user_emails must be present")
    end

    removed_user_ids = GroupManager.new(group).remove(users.map(&:id))
    GroupActionLogger.new(guardian.user, group).bulk_log_remove_users_from_group(removed_user_ids)

    removed_usernames = []
    skipped_usernames = []
    member_ids = group.users.where(id: users.map(&:id)).pluck(:id).to_set

    users.each do |user|
      if removed_user_ids.include?(user.id)
        removed_usernames << user.username
      elsif !member_ids.include?(user.id)
        skipped_usernames << user.username
      else
        raise Discourse::InvalidParameters
      end
    end

    { usernames: removed_usernames, skipped_usernames: }
  end

  private

  attr_reader :guardian, :group, :selectors
end
