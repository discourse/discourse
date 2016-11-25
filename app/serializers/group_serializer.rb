class GroupSerializer < BasicGroupSerializer
  attributes :mentionable

  def mentionable
    object.mentionable?(scope.user, object.id)
  end

  def include_mentionable?
    authenticated?
  end
end
