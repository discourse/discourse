class BasicGroupSerializer < ApplicationSerializer
  attributes :id,
             :automatic,
             :name,
             :user_count,
             :alias_level,
             :visible,
             :can_manage

  def can_manage
    true
  end

  def include_can_manage?
    scope && scope.can_edit?(object)
  end

end
