# frozen_string_literal: true

class GroupPostUserSerializer < BasicUserSerializer
  attributes :title, :name, :primary_group_name

  def primary_group_name
    object.primary_group.name if object.primary_group
  end
end
