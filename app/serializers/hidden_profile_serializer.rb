# frozen_string_literal: true

class HiddenProfileSerializer < BasicUserSerializer
  root 'hidden_profile'

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
