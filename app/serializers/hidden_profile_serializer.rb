class HiddenProfileSerializer < BasicUserSerializer
  attributes(
    :profile_hidden?,
    :title,
    :primary_group_name
  )

  def profile_hidden?
    true
  end

  def primary_group_name
    object.primary_group.try(:name)
  end
end
