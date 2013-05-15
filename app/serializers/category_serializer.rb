class CategorySerializer < BasicCategorySerializer

  attributes :secure, :groups, :available_groups, :auto_close_days

  def groups
    @groups ||= object.groups.order("name").all.map(&:name)
  end

  def available_groups
    Group.order("name").map(&:name) - groups
  end

end
