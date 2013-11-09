class CategorySerializer < BasicCategorySerializer

  attributes :read_restricted, :available_groups, :auto_close_days, :group_permissions, :position

  def group_permissions
    @group_permissions ||= begin
      perms = object.category_groups.joins(:group).includes(:group).order("groups.name").map do |cg|
        {
          permission_type: cg.permission_type,
          group_name: cg.group.name
        }
      end
      if perms.length == 0 && !object.read_restricted
        perms << {permission_type: CategoryGroup.permission_types[:full], group_name: :everyone}
      end
      perms
    end
  end

  def available_groups
    Group.order(:name).pluck(:name) - group_permissions.map{|g| g[:group_name]}
  end

end
