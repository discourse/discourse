# frozen_string_literal: true

class AdminCategoryBadgeSerializer < CategoryBadgeSerializer
  def include_parent_category_id?
    true
  end
end
