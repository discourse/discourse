# frozen_string_literal: true

class GroupUserAssignedSerializer < BasicUserSerializer
  attributes :assignments_count, :username_lower

  def include_assignments_count
    object.can_assign?
  end
end
