class GroupShowSerializer < BasicGroupSerializer
  attributes :is_group_user

  def include_is_group_user?
    scope.authenticated?
  end

  def is_group_user
    object.users.include?(scope.user)
  end
end
