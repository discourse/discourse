class TagGroupSerializer < ApplicationSerializer
  attributes :id, :name, :tag_names, :parent_tag_name, :one_per_topic, :permissions

  def tag_names
    object.tags.map(&:name).sort
  end

  def parent_tag_name
    [object.parent_tag.try(:name)].compact
  end

  def permissions
    @permissions ||= begin
      h = {}
      object.tag_group_permissions.joins(:group).includes(:group).order("groups.name").each do |tgp|
        h[tgp.group.name] = tgp.permission_type
      end
      if h.size == 0
        h['everyone'] = TagGroupPermission.permission_types[:full]
      end
      h
    end
  end
end
