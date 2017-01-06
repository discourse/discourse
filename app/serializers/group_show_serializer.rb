class GroupShowSerializer < BasicGroupSerializer
  attributes :is_group_user, :is_group_owner

  def include_is_group_user?
    scope.authenticated?
  end

  def is_group_user
    !!fetch_group_user
  end

  def include_is_group_owner?
    scope.authenticated?
  end

  def is_group_owner
    scope.is_admin? || fetch_group_user&.owner
  end

  private

  def fetch_group_user
    @group_user ||= object.group_users.find_by(user: scope.user)
  end
end
