class CategorySerializer < BasicCategorySerializer

  attributes :read_restricted,
             :available_groups,
             :auto_close_hours,
             :auto_close_based_on_last_post,
             :group_permissions,
             :position,
             :email_in,
             :email_in_allow_strangers,
             :suppress_from_homepage,
             :can_delete,
             :cannot_delete_reason,
             :is_special,
             :allow_badges,
             :custom_fields,
             :allowed_tags

  def group_permissions
    @group_permissions ||= begin
      perms = object.category_groups.joins(:group).includes(:group).order("groups.name").map do |cg|
        {
          permission_type: cg.permission_type,
          group_name: cg.group.name
        }
      end
      if perms.length == 0 && !object.read_restricted
        perms << { permission_type: CategoryGroup.permission_types[:full], group_name: :everyone }
      end
      perms
    end
  end

  def available_groups
    Group.order(:name).pluck(:name) - group_permissions.map{|g| g[:group_name]}
  end

  def can_delete
    true
  end

  def include_is_special?
    [SiteSetting.lounge_category_id, SiteSetting.meta_category_id, SiteSetting.staff_category_id, SiteSetting.uncategorized_category_id]
    .include? object.id
  end

  def is_special
    true
  end

  def include_can_delete?
    scope && scope.can_delete?(object)
  end

  def cannot_delete_reason
    scope && scope.cannot_delete_category_reason(object)
  end

  def include_cannot_delete_reason
    !include_can_delete? && scope && scope.can_edit?(object)
  end

  def include_email_in?
    scope && scope.can_edit?(object)
  end

  def include_email_in_allow_strangers?
    scope && scope.can_edit?(object)
  end

  def include_suppress_from_homepage?
    scope && scope.can_edit?(object)
  end

  def notification_level
   user = scope && scope.user
   object.notification_level ||
     (user && CategoryUser.where(user: user, category: object).first.try(:notification_level))
  end

  def include_allowed_tags?
    SiteSetting.tagging_enabled
  end

  def allowed_tags
    object.tags.pluck(:name)
  end

end
